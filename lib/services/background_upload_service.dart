import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundUploadService {
  static const String _channelId = 'upload_channel';
  static const String _channelName = 'تحميل الملفات';
  static const String _channelDescription = 'عرض تقدم رفع الملفات في الخلفية';

  static final FlutterLocalNotificationsPlugin _notificationPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isServiceRunning = false;

  /// تهيئة الخدمة
  static Future<void> initialize() async {
    try {
      final service = FlutterBackgroundService();

      // تهيئة الإشعارات
      await _initializeNotifications();

      // تكوين الخدمة
      await service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false, // جعلها false لمنع البدء التلقائي
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          isForegroundMode: true,
          autoStart: false, // جعلها false لمنع البدء التلقائي
          autoStartOnBoot: false, // جعلها false لمنع البدء التلقائي
          notificationChannelId: _channelId,
          initialNotificationTitle: 'خدمة الرفع',
          initialNotificationContent: 'جاهزة للرفع في الخلفية',
          foregroundServiceNotificationId: 888,
        ),
      );

      if (kDebugMode) {
        print('تم تهيئة BackgroundUploadService بنجاح');
      }
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في تهيئة BackgroundUploadService: $e');
      }
      // عدم إيقاف التطبيق حتى لو فشلت التهيئة
    }
  }

  /// بدء رفع مسلسل كامل
  static Future<void> startSeriesUpload({
    required String seriesName,
    required String seriesDescription,
    required String seriesImagePath,
    required List<Map<String, dynamic>> episodes,
    required String category,
    required String year,
  }) async {
    try {
      // تفعيل منع النوم
      await WakelockPlus.enable();

      // إنشاء بيانات المسلسل
      final seriesData = {
        'seriesName': seriesName,
        'seriesDescription': seriesDescription,
        'seriesImagePath': seriesImagePath,
        'episodes': episodes,
        'category': category,
        'year': year,
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
        'currentEpisodeIndex': 0,
        'uploadId': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      // حفظ بيانات الرفع
      await _savePendingUpload(seriesData);

      // بدء الخدمة
      final service = FlutterBackgroundService();
      if (!_isServiceRunning) {
        await service.startService();
        _isServiceRunning = true;
      }

      // إرسال أمر بدء الرفع
      service.invoke('start_series_upload', seriesData);

      // إظهار إشعار البداية
      await _showNotification(
        id: 1,
        title: 'بدء رفع المسلسل',
        body: 'بدء رفع "$seriesName" (${episodes.length} حلقة)',
        progress: 0,
        maxProgress: episodes.length,
      );
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في بدء رفع المسلسل: $e');
      }
    }
  }

  /// حفظ بيانات الرفع المعلق
  static Future<void> _savePendingUpload(
    Map<String, dynamic> uploadData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> pendingUploads = [];

    // تحميل البيانات المحفوظة
    final savedUploads = prefs.getString('pending_uploads');
    if (savedUploads != null) {
      final List<dynamic> uploadsList = jsonDecode(savedUploads);
      pendingUploads = uploadsList
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    pendingUploads.add(uploadData);
    await prefs.setString('pending_uploads', jsonEncode(pendingUploads));
  }

  /// تهيئة الإشعارات
  static Future<void> _initializeNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
      );

      await _notificationPlugin.initialize(settings);

      // إنشاء قناة الإشعارات
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.low,
        showBadge: false,
      );

      await _notificationPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      if (kDebugMode) {
        print('تم تهيئة الإشعارات بنجاح');
      }
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في تهيئة الإشعارات: $e');
      }
      // عدم إيقاف التطبيق حتى لو فشلت تهيئة الإشعارات
    }
  }

  /// بدء عملية رفع في الخلفية
  static Future<void> startUpload({
    required String filePath,
    required String uploadUrl,
    required String fileName,
    required Map<String, String> additionalData,
  }) async {
    try {
      // تشغيل WakeLock لمنع النوم
      await WakelockPlus.enable();

      // حفظ معلومات الرفع
      final prefs = await SharedPreferences.getInstance();
      final uploadData = {
        'filePath': filePath,
        'uploadUrl': uploadUrl,
        'fileName': fileName,
        'additionalData': additionalData,
        'startTime': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('current_upload', jsonEncode(uploadData));

      // بدء الخدمة
      final service = FlutterBackgroundService();
      if (!_isServiceRunning) {
        await service.startService();
        _isServiceRunning = true;
      }

      // إرسال بيانات الرفع للخدمة
      service.invoke('start_upload', uploadData);
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في بدء الرفع: $e');
      }
    }
  }

  /// إيقاف الرفع
  static Future<void> stopUpload() async {
    try {
      await WakelockPlus.disable();

      final service = FlutterBackgroundService();
      service.invoke('stop_upload');

      // مسح بيانات الرفع المحفوظة
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_upload');
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في إيقاف الرفع: $e');
      }
    }
  }

  /// دالة بدء الخدمة
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (kDebugMode) {
      print('بدء خدمة الرفع في الخلفية');
    }

    // التأكد من عدم توقف الخدمة
    await WakelockPlus.enable();

    service.on('start_upload').listen((event) async {
      await _handleUpload(service, event!);
    });

    service.on('start_series_upload').listen((event) async {
      await _handleSeriesUpload(service, event!);
    });

    service.on('stop_upload').listen((event) {
      service.stopSelf();
    });
  }

  /// معالجة رفع المسلسل
  static Future<void> _handleSeriesUpload(
    ServiceInstance service,
    Map<String, dynamic> seriesData,
  ) async {
    try {
      final String seriesName = seriesData['seriesName'] ?? 'مسلسل بدون اسم';
      final String seriesDescription = seriesData['seriesDescription'] ?? '';
      final String seriesImagePath = seriesData['seriesImagePath'] ?? '';
      final List<dynamic> episodesData = seriesData['episodes'] ?? [];
      final String category = seriesData['category'] ?? 'دراما';
      final String year = seriesData['year'] ?? DateTime.now().year.toString();

      const String baseUrl = 'https://dramaxbox.bbs.tr/App/api.php';

      // الخطوة 1: إنشاء المسلسل في قاعدة البيانات
      String? seriesId;
      String? imageUrl;

      // رفع صورة المسلسل إن وجدت
      if (seriesImagePath.isNotEmpty && File(seriesImagePath).existsSync()) {
        final imageRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl?action=upload_image'),
        );
        final imageFile = await http.MultipartFile.fromPath(
          'image',
          seriesImagePath,
        );
        imageRequest.files.add(imageFile);

        final imageResponse = await imageRequest.send();
        final imageResponseData = await imageResponse.stream.bytesToString();
        final imageJson = jsonDecode(imageResponseData);

        if (imageJson['status'] == 'success') {
          imageUrl = imageJson['image_path'];
        }
      }

      // إنشاء المسلسل
      final createResponse = await http.post(
        Uri.parse('$baseUrl?action=create_series'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': seriesName,
          'image_path': imageUrl ?? '',
          'description': seriesDescription,
          'category': category,
          'year': year,
          'replace_existing': true,
        }),
      );

      final createData = jsonDecode(createResponse.body);
      if (createData['status'] != 'success') {
        throw Exception('فشل إنشاء المسلسل: ${createData['message']}');
      }

      seriesId = createData['series_id'].toString();

      // الخطوة 2: رفع جميع الحلقات واحدة تلو الأخرى
      for (int i = 0; i < episodesData.length; i++) {
        final episodeData = Map<String, dynamic>.from(episodesData[i]);
        final int episodeNumber = i + 1;
        final String videoPath = episodeData['videoPath'] ?? '';
        final String episodeTitle =
            episodeData['title'] ?? 'الحلقة $episodeNumber';

        if (videoPath.isEmpty || !File(videoPath).existsSync()) {
          throw Exception('ملف الفيديو غير موجود: $videoPath');
        }

        // إظهار تقدم الرفع
        await _showNotification(
          id: 1,
          title: 'رفع $seriesName',
          body: 'رفع الحلقة $episodeNumber من ${episodesData.length}',
          progress: i,
          maxProgress: episodesData.length,
        );

        // رفع الحلقة
        final episodeRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl?action=upload_episode'),
        );

        episodeRequest.fields['series_id'] = seriesId;
        episodeRequest.fields['episode_number'] = episodeNumber.toString();
        episodeRequest.fields['title'] = episodeTitle;
        episodeRequest.fields['description'] = episodeData['description'] ?? '';
        episodeRequest.fields['season'] =
            episodeData['season']?.toString() ?? '1';

        // إضافة ملف الفيديو
        final videoFile = await http.MultipartFile.fromPath(
          'video',
          videoPath,
          filename:
              'episode_${episodeNumber}_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        episodeRequest.files.add(videoFile);

        // إرسال الطلب
        final episodeResponse = await episodeRequest.send();
        final episodeResponseData = await episodeResponse.stream
            .bytesToString();
        final episodeJson = jsonDecode(episodeResponseData);

        if (episodeJson['status'] != 'success') {
          throw Exception(
            'فشل رفع الحلقة $episodeNumber: ${episodeJson['message']}',
          );
        }

        // تحديث التقدم في التطبيق
        service.invoke('upload_progress', {
          'seriesName': seriesName,
          'episodeNumber': episodeNumber,
          'totalEpisodes': episodesData.length,
          'progress': ((i + 1) * 100 / episodesData.length).round(),
        });
      }

      // اكتمال رفع المسلسل
      await _showNotification(
        id: 1,
        title: 'تم رفع المسلسل بنجاح! 🎉',
        body: 'تم رفع "$seriesName" كاملاً (${episodesData.length} حلقة)',
        progress: episodesData.length,
        maxProgress: episodesData.length,
      );

      service.invoke('upload_completed', {
        'seriesName': seriesName,
        'seriesId': seriesId,
        'totalEpisodes': episodesData.length,
      });
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في رفع المسلسل: $e');
      }

      await _showNotification(
        id: 1,
        title: 'فشل رفع المسلسل ❌',
        body: 'خطأ: ${e.toString()}',
      );

      service.invoke('upload_error', {
        'seriesName': seriesData['seriesName'] ?? 'مجهول',
        'error': e.toString(),
      });
    } finally {
      // إيقاف WakeLock بعد انتهاء الرفع
      await WakelockPlus.disable();

      // إيقاف الخدمة بعد 5 ثوان من انتهاء الرفع
      Future.delayed(const Duration(seconds: 5), () {
        service.stopSelf();
      });
    }
  }

  /// معالجة الرفع
  static Future<void> _handleUpload(
    ServiceInstance service,
    Map<String, dynamic> uploadData,
  ) async {
    try {
      final String filePath = uploadData['filePath'];
      final String uploadUrl = uploadData['uploadUrl'];
      final String fileName = uploadData['fileName'];
      final Map<String, String> additionalData = Map<String, String>.from(
        uploadData['additionalData'] ?? {},
      );

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('الملف غير موجود: $filePath');
      }

      // إظهار إشعار البداية
      await _showNotification(
        id: 1,
        title: 'بدء الرفع',
        body: 'رفع الملف: $fileName',
        progress: 0,
        maxProgress: 100,
      );

      // إنشاء طلب الرفع
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // إضافة البيانات الإضافية
      request.fields.addAll(additionalData);

      // إضافة الملف
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      );
      request.files.add(multipartFile);

      // إرسال الطلب مع تتبع التقدم
      final streamedResponse = await request.send();
      final totalBytes = streamedResponse.contentLength ?? 0;
      int uploadedBytes = 0;

      // قراءة الاستجابة مع تتبع التقدم
      List<int> responseData = [];
      await for (var chunk in streamedResponse.stream) {
        responseData.addAll(chunk);
        uploadedBytes += chunk.length;
        final progress = totalBytes > 0
            ? (uploadedBytes * 100 / totalBytes).round()
            : 0;

        // تحديث الإشعار
        await _showNotification(
          id: 1,
          title: 'جاري الرفع...',
          body: '$fileName - $progress%',
          progress: progress,
          maxProgress: 100,
        );

        // إرسال التحديث للتطبيق
        service.invoke('upload_progress', {
          'fileName': fileName,
          'progress': progress,
          'uploadedBytes': uploadedBytes,
          'totalBytes': totalBytes,
        });
      }

      // إنشاء الاستجابة النهائية
      final response = http.Response.bytes(
        responseData,
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
      );

      // معالجة النتيجة
      if (response.statusCode == 200) {
        await _showNotification(
          id: 1,
          title: 'تم الرفع بنجاح',
          body: 'تم رفع $fileName بنجاح',
          progress: 100,
          maxProgress: 100,
        );

        service.invoke('upload_success', {
          'fileName': fileName,
          'response': response.body,
        });
      } else {
        throw Exception('فشل الرفع: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في الرفع: $e');
      }

      await _showNotification(
        id: 1,
        title: 'فشل الرفع',
        body: 'فشل في رفع الملف: ${e.toString()}',
      );

      service.invoke('upload_error', {'error': e.toString()});
    } finally {
      // إيقاف WakeLock
      await WakelockPlus.disable();

      // إيقاف الخدمة بعد انتهاء الرفع
      Future.delayed(const Duration(seconds: 3), () {
        service.stopSelf();
      });
    }
  }

  /// إظهار إشعار مع شريط تقدم
  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: progress != null && maxProgress != null,
      maxProgress: maxProgress ?? 0,
      progress: progress ?? 0,
      autoCancel: false,
      ongoing: progress != null && progress < 100,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notificationPlugin.show(id, title, body, details);
  }

  /// للـ iOS
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// التحقق من حالة الخدمة
  static bool get isServiceRunning => _isServiceRunning;
}
