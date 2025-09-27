import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Upload lifecycle states
enum UploadStatus {
  idle,
  preparing,
  uploadingImage,
  creatingSeries,
  uploadingEpisodes,
  paused,
  completed,
  canceled,
  error,
}

/// Data passed to start an upload
class UploadRequest {
  final String seriesName;
  final String? imagePath; // compressed if available
  final List<String> episodePaths; // ordered parts
  UploadRequest({
    required this.seriesName,
    required this.imagePath,
    required this.episodePaths,
  });
}

class UploadProgressSnapshot {
  final UploadStatus status;
  final double overallProgress; // 0..1 across all steps
  final double currentEpisodeProgress; // 0..1 for current episode file
  final int currentEpisodeNumber; // 1-based
  final int totalEpisodes;
  final String message;
  final bool isBusy;
  final bool canCancel;
  const UploadProgressSnapshot({
    required this.status,
    required this.overallProgress,
    required this.currentEpisodeProgress,
    required this.currentEpisodeNumber,
    required this.totalEpisodes,
    required this.message,
    required this.isBusy,
    required this.canCancel,
  });

  UploadProgressSnapshot copyWith({
    UploadStatus? status,
    double? overallProgress,
    double? currentEpisodeProgress,
    int? currentEpisodeNumber,
    int? totalEpisodes,
    String? message,
    bool? isBusy,
    bool? canCancel,
  }) => UploadProgressSnapshot(
    status: status ?? this.status,
    overallProgress: overallProgress ?? this.overallProgress,
    currentEpisodeProgress:
        currentEpisodeProgress ?? this.currentEpisodeProgress,
    currentEpisodeNumber: currentEpisodeNumber ?? this.currentEpisodeNumber,
    totalEpisodes: totalEpisodes ?? this.totalEpisodes,
    message: message ?? this.message,
    isBusy: isBusy ?? this.isBusy,
    canCancel: canCancel ?? this.canCancel,
  );
}

/// Singleton manager that keeps upload progress in memory so UI across
/// navigation stacks (and even after returning to home) can reflect
/// the same state. (Does not persist after app process kill.)
class UploadManager {
  UploadManager._internal();
  static final UploadManager instance = UploadManager._internal();

  final _controller = StreamController<UploadProgressSnapshot>.broadcast();
  Stream<UploadProgressSnapshot> get stream => _controller.stream;

  UploadProgressSnapshot _snapshot = const UploadProgressSnapshot(
    status: UploadStatus.idle,
    overallProgress: 0,
    currentEpisodeProgress: 0,
    currentEpisodeNumber: 0,
    totalEpisodes: 0,
    message: 'لا يوجد رفع حالياً',
    isBusy: false,
    canCancel: false,
  );

  CancelToken? _cancelToken;
  // Keep track of latest episode file paths used in last upload attempt so we
  // can delete them automatically after a fully successful upload, and also
  // allow user-triggered cleanup ("تنظيف الدليل"). These are absolute paths
  // created by the cutter screen and passed in the UploadRequest.
  List<String> _lastEpisodePaths = [];
  bool _autoDeletedAfterSuccess = false;
  bool _paused = false;

  /// Public flag so UI can show if local episodes remain.
  bool get hasLocalEpisodes =>
      _lastEpisodePaths.isNotEmpty && !_autoDeletedAfterSuccess;
  bool get isUploading =>
      _snapshot.status != UploadStatus.idle &&
      _snapshot.status != UploadStatus.completed &&
      _snapshot.status != UploadStatus.error &&
      _snapshot.status != UploadStatus.canceled;

  bool get isPaused => _snapshot.status == UploadStatus.paused;

  void _emit() {
    if (!_controller.isClosed) _controller.add(_snapshot);
  }

  Future<void> startUpload(UploadRequest request) async {
    if (isUploading) return; // ignore parallel calls
    if (request.episodePaths.isEmpty) return;

    _cancelToken = CancelToken();
    _lastEpisodePaths = List<String>.from(request.episodePaths);
    _autoDeletedAfterSuccess = false;
    _snapshot = _snapshot.copyWith(
      status: UploadStatus.preparing,
      overallProgress: 0,
      currentEpisodeProgress: 0,
      currentEpisodeNumber: 0,
      totalEpisodes: request.episodePaths.length,
      message: 'بدء التحضير...',
      isBusy: true,
      canCancel: true,
    );
    _emit();

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 5),
        contentType: 'multipart/form-data',
        headers: {
          'User-Agent': 'DramaXBox-Admin/1.0',
          'Accept': 'application/json',
          'Connection': 'keep-alive',
        },
        followRedirects: true,
        maxRedirects: 3,
      ),
    );

    // إضافة interceptor للتعامل مع الأخطاء
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            // إعادة المحاولة مرة واحدة للـ timeout
            try {
              final response = await dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: Options(
                  method: error.requestOptions.method,
                  headers: error.requestOptions.headers,
                  sendTimeout: const Duration(minutes: 40),
                  receiveTimeout: const Duration(minutes: 10),
                ),
              );
              handler.resolve(response);
              return;
            } catch (_) {
              // If retry fails, continue with original error
            }
          }
          handler.next(error);
        },
      ),
    );
    try {
      // 1) Upload image
      _snapshot = _snapshot.copyWith(
        status: UploadStatus.uploadingImage,
        message: 'جاري رفع صورة المسلسل...',
      );
      _emit();
      final remoteImageName = await _uploadImageIfNeeded(
        dio,
        request.imagePath,
      );

      // 2) Create series
      _snapshot = _snapshot.copyWith(
        status: UploadStatus.creatingSeries,
        message: 'جاري إنشاء المسلسل...',
      );
      _emit();
      final seriesId = await _createSeries(
        dio,
        request.seriesName,
        remoteImageName,
      );

      // 3) Upload episodes sequentially
      int uploaded = 0;
      for (int i = 0; i < request.episodePaths.length; i++) {
        if (_cancelToken?.isCancelled == true) break;
        // انتظار في حالة الإيقاف المؤقت قبل بدء الحلقة التالية
        while (_paused && !(_cancelToken?.isCancelled ?? false)) {
          if (_snapshot.status != UploadStatus.paused) {
            _snapshot = _snapshot.copyWith(
              status: UploadStatus.paused,
              message: 'موقوف مؤقتاً - الحلقة التالية بانتظار الاستئناف',
              canCancel: true,
            );
            _emit();
          }
          await Future.delayed(const Duration(milliseconds: 350));
        }
        final episodeNumber = i + 1;
        _snapshot = _snapshot.copyWith(
          status: UploadStatus.uploadingEpisodes,
          currentEpisodeNumber: episodeNumber,
          currentEpisodeProgress: 0,
          message:
              'رفع الحلقة $episodeNumber من ${request.episodePaths.length}',
        );
        _emit();

        await _uploadEpisode(
          dio: dio,
          seriesId: seriesId,
          episodeNumber: episodeNumber,
          filePath: request.episodePaths[i],
        );
        if (_cancelToken?.isCancelled == true) break;
        uploaded++;
        _snapshot = _snapshot.copyWith(
          overallProgress: uploaded / request.episodePaths.length,
          message: 'تم رفع الحلقة $episodeNumber',
        );
        _emit();
      }

      if (_cancelToken?.isCancelled == true) {
        _snapshot = _snapshot.copyWith(
          status: UploadStatus.canceled,
          message:
              'تم إلغاء الرفع بعد رفع ${_snapshot.currentEpisodeNumber - 1} حلقة',
          isBusy: false,
          canCancel: false,
        );
        _emit();
        return;
      }

      _snapshot = _snapshot.copyWith(
        status: UploadStatus.completed,
        overallProgress: 1,
        currentEpisodeProgress: 1,
        message: 'اكتمل رفع المسلسل (${request.episodePaths.length} حلقة)',
        isBusy: false,
        canCancel: false,
      );
      _emit();

      // Attempt auto deletion of local episode files after full success.
      await _deleteLocalEpisodesInternal();
      _autoDeletedAfterSuccess = true;
      // Emit again to reflect that local files are cleaned.
      _emit();
    } catch (e, st) {
      if (kDebugMode) {
        print('Upload error: $e\n$st');
      }
      final canceled = (e is DioException && CancelToken.isCancel(e));
      _snapshot = _snapshot.copyWith(
        status: canceled ? UploadStatus.canceled : UploadStatus.error,
        message: canceled ? 'تم الإلغاء' : 'فشل الرفع: $e',
        isBusy: false,
        canCancel: false,
      );
      _emit();
    }
  }

  void cancelUpload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('user_cancel');
    }
  }

  void pauseUpload() {
    if (isUploading && !isPaused) {
      _paused = true;
    }
  }

  void resumeUpload() {
    if (_paused) {
      _paused = false;
      // سيقوم الحلقة الرئيسية بالاستئناف؛ نحرك الحالة فوراً إذا كانت متوقفة
      if (isPaused) {
        _snapshot = _snapshot.copyWith(
          status: UploadStatus.uploadingEpisodes,
          message: 'استئناف الرفع...',
        );
        _emit();
      }
    }
  }

  /// Manually clean local episode files (used by toolbar button). Emits a
  /// snapshot update if cleanup changes state. Safe to call multiple times.
  Future<void> cleanLocalEpisodes() async {
    final hadFiles = hasLocalEpisodes;
    await _deleteLocalEpisodesInternal();
    _autoDeletedAfterSuccess = true; // treat as cleaned
    if (hadFiles) {
      _emit();
    }
  }

  Future<void> _deleteLocalEpisodesInternal() async {
    for (final path in _lastEpisodePaths) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // Ignore individual deletion errors.
      }
    }
    _lastEpisodePaths.clear();
  }

  Future<String> _uploadImageIfNeeded(Dio dio, String? imagePath) async {
    if (imagePath == null) throw Exception('صورة المسلسل مطلوبة');
    final file = File(imagePath);
    if (!await file.exists()) throw Exception('ملف الصورة غير موجود');
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    });
    final resp = await dio.post(
      'https://dramaxbox.bbs.tr/App/api.php?action=upload_image',
      data: form,
      cancelToken: _cancelToken,
    );
    final data = resp.data is Map ? resp.data : jsonDecode(resp.data);
    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'فشل رفع الصورة');
    }
    return data['image_path'];
  }

  Future<int> _createSeries(
    Dio dio,
    String name,
    String remoteImageName,
  ) async {
    final body = {
      'name': name,
      'image_path': remoteImageName,
      'replace_existing': true,
    };
    final resp = await dio.post(
      'https://dramaxbox.bbs.tr/App/api.php?action=create_series',
      data: jsonEncode(body),
      options: Options(contentType: 'application/json'),
      cancelToken: _cancelToken,
    );
    final data = resp.data is Map ? resp.data : jsonDecode(resp.data);
    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'تعذر إنشاء المسلسل');
    }
    return data['series_id'];
  }

  Future<void> _uploadEpisode({
    required Dio dio,
    required int seriesId,
    required int episodeNumber,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('ملف الحلقة مفقود: $filePath');

    final fileSize = await file.length();
    if (fileSize == 0) throw Exception('ملف الحلقة فارغ');

    // التحقق من صلاحيات الوصول للملف
    try {
      await file.readAsBytes();
    } catch (e) {
      throw Exception('لا يمكن قراءة ملف الحلقة: $e');
    }

    int retryCount = 0;
    const maxRetries = 5; // زيادة المحاولات للـ 502 المؤقتة

    while (retryCount < maxRetries) {
      try {
        final form = FormData.fromMap({
          'series_id': seriesId.toString(),
          'episode_number': episodeNumber.toString(),
          'title': 'حلقة $episodeNumber',
          'video': await MultipartFile.fromFile(
            file.path,
            filename:
                'episode_${episodeNumber}_${DateTime.now().millisecondsSinceEpoch}.mp4',
          ),
        });

        final response = await dio.post(
          'https://dramaxbox.bbs.tr/App/api.php?action=upload_episode',
          data: form,
          cancelToken: _cancelToken,
          onSendProgress: (sent, total) {
            if (total > 0) {
              _snapshot = _snapshot.copyWith(
                currentEpisodeProgress: sent / total,
              );
              _emit();
            }
          },
        );

        // التحقق من استجابة الخادم
        final data = response.data is Map
            ? response.data
            : jsonDecode(response.data);
        if (data['status'] != 'success') {
          final errorMessage = data['message'] ?? 'فشل رفع الحلقة';
          throw Exception('خطأ من الخادم: $errorMessage');
        }

        // نجح الرفع، خروج من الحلقة
        break;
      } catch (e) {
        retryCount++;
        if (e is DioException) {
          final code = e.response?.statusCode;
          final dioType = e.type;
          // أخطاء لا فائدة من إعادة المحاولة لها
          if (code != null && code >= 400 && code < 500 && code != 429) {
            if (code == 413) {
              throw Exception(
                'الحلقة كبيرة جداً (413). قلل المدة أو أعد ترميز الفيديو',
              );
            }
            throw Exception(
              'رفض الخادم (HTTP $code) لن يُعاد المحاولة: ${e.message}',
            );
          }
          if (retryCount >= maxRetries) {
            if (code == 502 || code == 503 || code == 504) {
              throw Exception(
                'فشل الخادم (HTTP $code) بعد عدة محاولات. حاول لاحقاً أو تحقق من إعدادات الخادم',
              );
            }
            if (dioType == DioExceptionType.connectionTimeout) {
              throw Exception(
                'انتهت مهلة الاتصال بعد عدة محاولات – تأكد من الشبكة',
              );
            }
            if (dioType == DioExceptionType.sendTimeout) {
              throw Exception(
                'مهلة الإرسال انتهت بعد عدة محاولات – الحجم أو السرعة بطيئة',
              );
            }
            throw Exception(
              'فشل رفع الحلقة بعد $maxRetries محاولات: ${e.toString()}',
            );
          }
        } else if (retryCount >= maxRetries) {
          throw Exception('فشل رفع الحلقة: ${e.toString()}');
        }

        // انتظار قبل المحاولة التالية (Exponential Backoff)
        final backoffSeconds = pow(2, retryCount).toInt();
        await Future.delayed(Duration(seconds: backoffSeconds));
      }
    }
  }

  void dispose() {
    _controller.close();
  }
}
