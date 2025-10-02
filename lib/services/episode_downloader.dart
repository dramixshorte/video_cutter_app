import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'app_logger.dart';

/// استثناء مخصص يغلف أخطاء التنزيل ويسهل عرض رسالة عربية واضحة للمستخدم
class DownloadException implements Exception {
  final String
  code; // مثل: network_timeout, server_404, size_too_small, cancelled, unknown
  final String message;
  final int? statusCode;
  DownloadException(this.code, this.message, {this.statusCode});
  @override
  String toString() => 'DownloadException($code, $message, status=$statusCode)';
}

/// EpisodeDownloader
/// خدمة بسيطة لتنزيل الحلقة إلى مساحة التطبيق (Sandbox) بدون طلب إذن التخزين
/// على أندرويد 10+ (Scoped Storage). يمكن لاحقاً إضافة تصدير إلى MediaStore.
class EpisodeDownloader {
  EpisodeDownloader._();
  static final EpisodeDownloader instance = EpisodeDownloader._();

  final Dio _dio = Dio();

  /// تنزيل ملف من [url] وحفظه في مجلد episodes داخل Documents.
  /// يعيد المسار المحلي النهائي أو يرمي استثناء عند الفشل.
  /// [onProgress] قيمة بين 0 و 1.
  Future<String> downloadEpisode({
    required String url,
    required dynamic id,
    void Function(double p)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (url.isEmpty) throw DownloadException('empty_url', 'الرابط فارغ');

    final startTs = DateTime.now();
    await AppLogger.instance.log(
      'download_start',
      data: {'id': id.toString(), 'url': url},
    );

    // Determine base directory: use public Downloads on Android, or Downloads on other platforms, fallback to app docs
    Directory baseDir;
    if (Platform.isAndroid) {
      baseDir = Directory('/storage/emulated/0/Download');
    } else {
      try {
        baseDir =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      } catch (_) {
        baseDir = await getApplicationDocumentsDirectory();
      }
    }
    final dir = Directory('${baseDir.path}/episodes_dramix_short');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    // Force video file extension to .mp4 (ignore URL path extension)
    const String ext = 'mp4';

    String baseName = 'episode_$id';
    String candidate = '${dir.path}/$baseName.$ext';
    int attempt = 1;
    while (File(candidate).existsSync() && attempt < 50) {
      candidate = '${dir.path}/$baseName(${attempt++}).$ext';
    }

    // HEAD request (best effort) لمعرفة الحجم المتوقع
    int? expectedSize;
    try {
      final headResp = await _dio.request(
        url,
        options: Options(
          method: 'HEAD',
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      expectedSize = int.tryParse(
        headResp.headers.value('content-length') ?? '',
      );
      await AppLogger.instance.log(
        'download_head',
        data: {'id': id.toString(), 'expected': expectedSize},
      );
    } catch (e) {
      await AppLogger.instance.log(
        'download_head_fail',
        data: {'id': id.toString(), 'error': e.toString()},
      );
    }

    // حساب الحد الأدنى الديناميكي
    int dynamicMin = 8 * 1024; // 8KB أساس
    if (expectedSize != null && expectedSize > 0) {
      final tenPercent = (expectedSize * 0.1).floor();
      dynamicMin = [dynamicMin, tenPercent, 30 * 1024]
          .where((v) => v > 0)
          .reduce((a, b) => a < b ? a : b); // أصغر قيمة من الثلاثة ولكن ≥ 8KB
      if (dynamicMin < 8 * 1024) dynamicMin = 8 * 1024;
    }

    final token = cancelToken ?? CancelToken();
    int lastMilestone = 0;
    try {
      await _dio.download(
        url,
        candidate,
        cancelToken: token,
        onReceiveProgress: (r, t) {
          if (t > 0) {
            final prog = r / t;
            if (onProgress != null) onProgress(prog);
            final milestone = (prog * 100).floor();
            if (milestone >= lastMilestone + 15 || milestone == 100) {
              lastMilestone = milestone;
              AppLogger.instance.log(
                'download_progress',
                data: {'id': id.toString(), 'p': milestone},
              );
            }
          } else {
            // لا يوجد إجمالي معروف (Transfer-Encoding: chunked أو بدون Content-Length)
            // نحاول استخدام expectedSize من HEAD، وإلا نولد نسبة تقديرية لإظهار حياة في الواجهة
            double pseudoProg;
            if (expectedSize != null && expectedSize > 0) {
              pseudoProg = (r / expectedSize).clamp(0.0, 0.98);
            } else {
              // بعد كل 256KB نتقدم تقريبياً، نقيدها عند 90%
              pseudoProg = math.min(0.90, r / (256 * 1024 * 10));
            }
            if (onProgress != null) onProgress(pseudoProg);
            final milestone = (pseudoProg * 100).floor();
            if (milestone >= lastMilestone + 20) {
              // أوسع حتى لا نكثر السجلات
              lastMilestone = milestone;
              AppLogger.instance.log(
                'download_progress_chunked',
                data: {
                  'id': id.toString(),
                  'bytes': r,
                  'p': milestone,
                  'expected': expectedSize,
                },
              );
            }
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        await AppLogger.instance.log(
          'download_cancelled',
          data: {'id': id.toString()},
        );
        throw DownloadException('cancelled', 'تم إلغاء التحميل');
      }
      final sc = e.response?.statusCode;
      final code = () {
        if (sc == 404) return 'server_404';
        if (sc == 403 || sc == 401) return 'server_forbidden';
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return 'network_timeout';
        }
        if (e.type == DioExceptionType.badResponse && sc == 302) {
          return 'redirect_loop';
        }
        return 'network_error';
      }();
      await AppLogger.instance.log(
        'download_fail',
        data: {
          'id': id.toString(),
          'code': code,
          'status': sc,
          'error': e.message,
        },
      );
      throw DownloadException(code, 'فشل التحميل (رمز $code)', statusCode: sc);
    } catch (e) {
      await AppLogger.instance.log(
        'download_fail',
        data: {'id': id.toString(), 'code': 'unknown', 'error': e.toString()},
      );
      throw DownloadException('unknown', 'خطأ غير متوقع أثناء التحميل');
    }

    final f = File(candidate);
    if (!f.existsSync()) {
      await AppLogger.instance.log(
        'download_post_missing',
        data: {'id': id.toString()},
      );
      throw DownloadException('missing_file', 'الملف غير موجود بعد التحميل');
    }
    final length = await f.length();
    if (length < dynamicMin) {
      try {
        f.deleteSync();
      } catch (_) {}
      await AppLogger.instance.log(
        'download_size_small',
        data: {'id': id.toString(), 'size': length, 'min': dynamicMin},
      );
      throw DownloadException('size_too_small', 'الحجم غير مكتمل (${length}B)');
    }
    onProgress?.call(1.0); // تأكد من إظهار مكتمل 100% في الواجهة قبل الإنهاء
    await AppLogger.instance.log(
      'download_complete',
      data: {
        'id': id.toString(),
        'size': length,
        'ms': DateTime.now().difference(startTs).inMilliseconds,
        'min': dynamicMin,
      },
    );
    return candidate;
  }
}
