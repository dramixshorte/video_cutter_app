import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_min_gpl/ffmpeg_kit.dart';
import 'app_logger.dart';

/// ThumbnailService
/// محاولة جذرية لتقليل أخطاء MediaMetadataRetriever عبر:
/// 1- التحقق من المسار (محلي/رابط) + وجود الملف المحلي.
/// 2- استعمال video_thumbnail مباشرة (المسار المحلي أفضل من الشبكة).
/// 3- في حال الفشل و المصدر URL: تنزيل جزء صغير (Range) ومحاولة ثانية.
/// 4- كحل أخير: استخراج إطار عبر FFmpeg (إخراج PNG) ثم إرجاع bytes.
/// يوجد منع تكرار (debounce) لنفس المفتاح خلال نافذة زمنية لمنع spam.
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  // تمنع تكرار الطلبات المكثفة لنفس الحلقة
  final Map<String, DateTime> _recent = {};
  final Map<String, int> _failCounts = {}; // عدد الفشل لكل idKey
  final Map<String, bool> _permanentNull = {}; // كاش دائم للفشل بعد الحد
  Duration debounceWindow = const Duration(seconds: 3);
  int maxFailuresBeforePermanent = 3;

  Future<Uint8List?> getThumbnail({
    required String idKey,
    required String videoPath,
    String? localPath,
    int maxWidth = 512,
    int quality = 75,
  }) async {
    // كاش فشل دائم: لا تحاول مجدداً
    if (_permanentNull[idKey] == true) {
      await AppLogger.instance.log('thumb_skip_permanent', data: {'id': idKey});
      return null;
    }

    // Debounce زمني بسيط لمنع الطلب المتكرر السريع
    final now = DateTime.now();
    final last = _recent[idKey];
    if (last != null && now.difference(last) < debounceWindow) {
      await AppLogger.instance.log(
        'thumb_skip_debounce',
        data: {'id': idKey, 'since_ms': now.difference(last).inMilliseconds},
      );
      return null; // تجاهل مؤقت
    }
    _recent[idKey] = now;

    // اختر مصدر المسار
    String? source;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      source = localPath;
    } else if (videoPath.isNotEmpty) {
      source = videoPath;
    }
    if (source == null || source.isEmpty) {
      await AppLogger.instance.log('thumb_no_source', data: {'id': idKey});
      return null;
    }

    final isRemote =
        source.startsWith('http://') || source.startsWith('https://');

    // فحص صلاحية الرابط قبل المحاولات المكلفة
    if (isRemote) {
      try {
        final head = await http.head(Uri.parse(source));
        final ct = head.headers['content-type']?.toLowerCase() ?? '';
        if (head.statusCode >= 400) {
          await _recordFailure(
            idKey,
            'head_${head.statusCode}',
            extra: {'ct': ct},
          );
          return null;
        }
        if (!ct.startsWith('video/') &&
            !ct.contains('mp4') &&
            !ct.contains('mpeg') &&
            !ct.contains('matroska')) {
          await _recordFailure(idKey, 'not_video', extra: {'ct': ct});
          return null;
        }
      } catch (e) {
        await _recordFailure(idKey, 'head_error', extra: {'err': e.toString()});
        // نكمل رغم فشل HEAD (قد يحظر السيرفر HEAD)
      }
    }

    // 1) محاولة مباشرة عبر plugin
    try {
      final data = await vt.VideoThumbnail.thumbnailData(
        video: source,
        imageFormat: vt.ImageFormat.PNG,
        maxWidth: maxWidth,
        quality: quality,
      );
      if (data != null) {
        await AppLogger.instance.log(
          'thumb_success_direct',
          data: {'id': idKey},
        );
        _failCounts.remove(idKey);
        return data;
      }
    } catch (e) {
      await _recordFailure(idKey, 'direct_fail', extra: {'err': e.toString()});
    }

    // 2) لو فشل وكان رابط: حمل جزء صغير Range
    if (isRemote) {
      try {
        final tempDir = await getTemporaryDirectory();
        final partial = File('${tempDir.path}/thumb_part_$idKey');
        final resp = await http.get(
          Uri.parse(source),
          headers: {'Range': 'bytes=0-250000'},
        );
        if (resp.statusCode == 200 || resp.statusCode == 206) {
          // فحص أول bytes لاحتمال HTML أو JSON (ليس فيديو)
          final sniff = utf8
              .decode(resp.bodyBytes.take(64).toList(), allowMalformed: true)
              .toLowerCase();
          if (sniff.contains('<html') ||
              sniff.contains('{"') ||
              sniff.contains('<!doctype')) {
            await _recordFailure(
              idKey,
              'partial_not_video',
              extra: {'prefix': sniff.substring(0, math.min(30, sniff.length))},
            );
            return null;
          }
          await partial.writeAsBytes(resp.bodyBytes, flush: true);
          try {
            final data = await vt.VideoThumbnail.thumbnailData(
              video: partial.path,
              imageFormat: vt.ImageFormat.PNG,
              maxWidth: maxWidth,
              quality: quality,
            );
            if (data != null) {
              await partial.delete().catchError((_) => partial);
              await AppLogger.instance.log(
                'thumb_success_partial',
                data: {'id': idKey},
              );
              _failCounts.remove(idKey);
              return data;
            }
          } catch (_) {}
          await partial.delete().catchError((_) => partial);
        }
      } catch (e) {
        await _recordFailure(
          idKey,
          'partial_fail',
          extra: {'err': e.toString()},
        );
      }
    }

    // 3) كحل أخير: محاولة عبر FFmpeg (أكثر موثوقية لبعض الصيغ)
    // الشرط: لو المصدر رابط يجب تنزيله كاملاً (هنا نتجنب هذا للحجم)، لذلك نطبق فقط على ملف محلي.
    try {
      String? ffmpegInput;
      if (File(source).existsSync()) ffmpegInput = source;
      if (ffmpegInput != null) {
        final outDir = await getTemporaryDirectory();
        final outFile = File('${outDir.path}/thumb_ffmpeg_$idKey.png');
        if (outFile.existsSync()) {
          try {
            outFile.deleteSync();
          } catch (_) {}
        }
        // استخراج إطار عند ثانية 1
        final cmd =
            "-y -i '${ffmpegInput.replaceAll("'", "\\'")}' -ss 00:00:01.000 -vframes 1 -vf scale=$maxWidth:-1 '${outFile.path}'";
        final sesh = await FFmpegKit.execute(cmd);
        final returnCode = await sesh.getReturnCode();
        if (returnCode != null &&
            returnCode.isValueSuccess() &&
            outFile.existsSync()) {
          final bytes = await outFile.readAsBytes();
          if (bytes.isNotEmpty) {
            await AppLogger.instance.log(
              'thumb_success_ffmpeg',
              data: {'id': idKey},
            );
            _failCounts.remove(idKey);
            return bytes;
          }
        }
      }
    } catch (e) {
      await _recordFailure(idKey, 'ffmpeg_fail', extra: {'err': e.toString()});
    }
    await _recordFailure(idKey, 'all_failed');
    return null; // فشل كل شيء
  }

  Future<void> _recordFailure(
    String idKey,
    String stage, {
    Map<String, dynamic>? extra,
  }) async {
    final c = (_failCounts[idKey] ?? 0) + 1;
    _failCounts[idKey] = c;
    await AppLogger.instance.log(
      'thumb_fail',
      data: {
        'id': idKey,
        'stage': stage,
        'count': c,
        if (extra != null) ...extra,
      },
    );
    if (c >= maxFailuresBeforePermanent) {
      _permanentNull[idKey] = true;
      await AppLogger.instance.log(
        'thumb_mark_permanent',
        data: {'id': idKey, 'final_stage': stage},
      );
    }
  }
}
