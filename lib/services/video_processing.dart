import 'dart:async';
import 'dart:io' show Platform, Directory;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:ffmpeg_kit_min_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

/// Result of processing (cutting) a video into segments.
class VideoProcessResult {
  final bool success;
  final List<String> parts; // absolute paths (or pseudo paths on web)
  final String? error;
  const VideoProcessResult.success(this.parts) : success = true, error = null;
  const VideoProcessResult.failure(this.error)
    : success = false,
      parts = const [];
}

/// Progress callback: partIndex starts from 1. totalParts may be null if غير معروف (مثل العشوائي).
typedef SegmentProgressCallback = void Function(int partIndex, int? totalParts);

/// Abstract processor – allows swapping implementations per platform.
abstract class BaseVideoProcessor {
  Future<VideoProcessResult> process({
    required String inputPath,
    required int segmentSeconds,
    SegmentProgressCallback? onPartComplete,
  });

  Future<VideoProcessResult> processRandom({
    required String inputPath,
    required int minSeconds,
    required int maxSeconds,
    SegmentProgressCallback? onPartComplete,
  }) async {
    // Default implementation falls back to fixed segmentation using maxSeconds
    return process(
      inputPath: inputPath,
      segmentSeconds: maxSeconds,
      onPartComplete: onPartComplete,
    );
  }
}

class _FfmpegVideoProcessor extends BaseVideoProcessor {
  @override
  Future<VideoProcessResult> process({
    required String inputPath,
    required int segmentSeconds,
    SegmentProgressCallback? onPartComplete,
  }) async {
    try {
      final duration = await _probeDuration(inputPath);
      if (duration <= 0) {
        // Attempt a minimal single-part pass (treat as unknown but proceed)
        final single = await _cutSingleCopy(inputPath);
        if (single != null) {
          return VideoProcessResult.success([single]);
        }
        return const VideoProcessResult.failure('مدة الفيديو غير صالحة');
      }

      // إذا كان طول الفيديو أقل من المدة المطلوبة -> قصه كجزء واحد فقط
      if (duration < segmentSeconds) {
        final single = await _cutSingleCopy(inputPath);
        if (single != null) return VideoProcessResult.success([single]);
      }

      final totalParts = (duration / segmentSeconds).ceil();
      final saveDir = await _resolveOutputDir();
      final List<String> parts = [];
      for (var i = 0; i < totalParts; i++) {
        final start = i * segmentSeconds;
        final remaining = duration - start;
        final currentDuration = remaining < segmentSeconds
            ? remaining
            : segmentSeconds;
        final outputPath = '${saveDir.path}/part_${i + 1}.mp4';
        final args = [
          '-y',
          '-ss',
          start.toString(),
          '-i',
          inputPath,
          '-t',
          currentDuration.toString(),
          '-c',
          'copy',
          '-avoid_negative_ts',
          '1',
          outputPath,
        ];
        final session = await FFmpegKit.executeWithArguments(args);
        final rc = await session.getReturnCode();
        if (rc == null || !rc.isValueSuccess()) {
          final logs = await session.getAllLogsAsString();
          return VideoProcessResult.failure(
            'فشل قص الجزء ${i + 1}: ${logs ?? 'خطأ'}',
          );
        }
        parts.add(outputPath);
        if (onPartComplete != null) onPartComplete(i + 1, totalParts);
      }
      return VideoProcessResult.success(parts);
    } catch (e) {
      if (kDebugMode) debugPrint('FFmpeg processing error: $e');
      return VideoProcessResult.failure(e.toString());
    }
  }

  @override
  Future<VideoProcessResult> processRandom({
    required String inputPath,
    required int minSeconds,
    required int maxSeconds,
    SegmentProgressCallback? onPartComplete,
  }) async {
    try {
      final duration = await _probeDuration(inputPath);
      if (duration <= 0) {
        final single = await _cutSingleCopy(inputPath);
        if (single != null) return VideoProcessResult.success([single]);
        return const VideoProcessResult.failure('مدة الفيديو غير صالحة');
      }
      if (duration <= minSeconds) {
        final single = await _cutSingleCopy(inputPath);
        if (single != null) return VideoProcessResult.success([single]);
      }
      final saveDir = await _resolveOutputDir();
      final List<String> parts = [];
      final rng = Random();
      double cursor = 0;
      int index = 0;
      while (cursor < duration - 0.5) {
        // tolerance
        final remaining = duration - cursor;
        final randomLen = remaining <= minSeconds
            ? remaining
            : min(
                remaining,
                (minSeconds + rng.nextInt((maxSeconds - minSeconds) + 1))
                    .toDouble(),
              );
        final outputPath = '${saveDir.path}/part_${index + 1}.mp4';
        final args = [
          '-y',
          '-ss',
          cursor.toString(),
          '-i',
          inputPath,
          '-t',
          randomLen.toString(),
          '-c',
          'copy',
          '-avoid_negative_ts',
          '1',
          outputPath,
        ];
        final session = await FFmpegKit.executeWithArguments(args);
        final rc = await session.getReturnCode();
        if (rc == null || !rc.isValueSuccess()) {
          final logs = await session.getAllLogsAsString();
          return VideoProcessResult.failure(
            'فشل قص الجزء العشوائي ${index + 1}: ${logs ?? 'خطأ'}',
          );
        }
        parts.add(outputPath);
        if (onPartComplete != null) {
          onPartComplete(index, null); // total غير معروف هنا
        }
        index++;
        cursor += randomLen;
      }
      if (parts.isEmpty) {
        // fallback: قص كامل الفيديو كجزء واحد
        final outputPath = '${saveDir.path}/part_1.mp4';
        final args = ['-y', '-i', inputPath, '-c', 'copy', outputPath];
        final session = await FFmpegKit.executeWithArguments(args);
        final rc = await session.getReturnCode();
        if (rc == null || !rc.isValueSuccess()) {
          return const VideoProcessResult.failure('تعذر توليد الأجزاء');
        }
        parts.add(outputPath);
      }
      return VideoProcessResult.success(parts);
    } catch (e) {
      if (kDebugMode) debugPrint('FFmpeg random processing error: $e');
      return VideoProcessResult.failure(e.toString());
    }
  }

  Future<double> _probeDuration(String path) async {
    try {
      // أولاً: محاولة استخراج سطر Duration عبر أمر معلومات فقط
      final probeSession = await FFmpegKit.execute('-i "$path" -hide_banner');
      final fullLogs = await probeSession.getAllLogsAsString() ?? '';
      final durMatch = RegExp(
        r'Duration: (\d+):(\d+):(\d+\.\d+)',
      ).firstMatch(fullLogs);
      if (durMatch != null) {
        final h = double.parse(durMatch.group(1)!);
        final m = double.parse(durMatch.group(2)!);
        final s = double.parse(durMatch.group(3)!);
        return h * 3600 + m * 60 + s;
      }
      // ثانياً: fallback القديم (قد يعطي 0 لكن نحاول)
      final session = await FFmpegKit.executeWithArguments([
        '-v',
        'error',
        '-i',
        path,
        '-f',
        'null',
        '-',
      ]);
      final logs = await session.getAllLogs();
      String? lastTime;
      for (final log in logs) {
        final line = log.getMessage();
        final idx = line.indexOf('time=');
        if (idx != -1) {
          final sub = line.substring(idx + 5);
          final p = sub.split(' ');
          if (p.isNotEmpty) lastTime = p.first;
        }
      }
      if (lastTime != null) {
        final segs = lastTime.split(':');
        if (segs.length == 3) {
          final h = double.tryParse(segs[0]) ?? 0;
          final m = double.tryParse(segs[1]) ?? 0;
          final s = double.tryParse(segs[2]) ?? 0;
          return h * 3600 + m * 60 + s;
        }
      }
      return 0;
    } catch (e) {
      if (kDebugMode) debugPrint('Probe duration failed: $e');
      return 0;
    }
  }

  Future<String?> _cutSingleCopy(String inputPath) async {
    try {
      final saveDir = await _resolveOutputDir();
      final outputPath = '${saveDir.path}/part_1.mp4';
      final args = ['-y', '-i', inputPath, '-c', 'copy', outputPath];
      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();
      if (rc != null && rc.isValueSuccess()) return outputPath;
    } catch (e) {
      if (kDebugMode) debugPrint('Single copy fail: $e');
    }
    return null;
  }

  Future<Directory> _resolveOutputDir() async {
    // Android: مجلد ثابت مطلوب حسب طلبك
    if (Platform.isAndroid) {
      try {
        final dir = Directory('/storage/emulated/0/Download/DramaxShort');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (e) {
        if (kDebugMode) debugPrint('Failed creating DramaxShort directory: $e');
      }
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final out = Directory('${docs.path}/video_cutter_parts');
        if (!await out.exists()) await out.create(recursive: true);
        return out;
      } catch (_) {}
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs;
  }
}

/// Web placeholder – real implementation could use ffmpeg_wasm or a server API.
class _WebVideoProcessor extends BaseVideoProcessor {
  @override
  Future<VideoProcessResult> process({
    required String inputPath,
    required int segmentSeconds,
    SegmentProgressCallback? onPartComplete,
  }) async {
    return const VideoProcessResult.failure(
      'القص المحلي غير مدعوم على الويب حالياً. سيتم لاحقاً إضافة معالجة عبر المتصفح أو الخادم.',
    );
  }
}

class VideoProcessor {
  VideoProcessor._();
  static final BaseVideoProcessor instance = _build();

  /// Helper to get output directory path for UI cleanup of stray parts.
  static Future<Directory> getOutputDirectory() async {
    if (instance is _FfmpegVideoProcessor) {
      return (instance as _FfmpegVideoProcessor)._resolveOutputDir();
    }
    return getApplicationDocumentsDirectory();
  }

  static BaseVideoProcessor _build() {
    if (kIsWeb) return _WebVideoProcessor();
    // Other platforms use ffmpeg implementation for now
    return _FfmpegVideoProcessor();
  }
}
