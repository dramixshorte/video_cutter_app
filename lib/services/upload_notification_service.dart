import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'upload_manager.dart';

/// IDs & channel configuration
class UploadNotificationService {
  static final UploadNotificationService instance =
      UploadNotificationService._();
  UploadNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription? _sub;

  static const _channelId = 'upload_progress_channel';
  static const _channelName = 'رفع الحلقات';
  static const _channelDesc =
      'إشعار مستمر يوضح تقدم رفع الحلقات مع تحكم بالإيقاف المؤقت والاستئناف.';
  static const _notificationId = 4440;

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    // Create channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.low,
      showBadge: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _initialized = true;
    _bindStream();
  }

  void _bindStream() {
    _sub?.cancel();
    _sub = UploadManager.instance.stream.listen(_onUploadUpdate);
  }

  Future<void> _onUploadUpdate(UploadProgressSnapshot snap) async {
    if (!_initialized) return;
    if (snap.status == UploadStatus.idle ||
        snap.status == UploadStatus.completed ||
        snap.status == UploadStatus.error ||
        snap.status == UploadStatus.canceled) {
      // Show a final summary then cancel after short delay
      if (snap.status == UploadStatus.completed) {
        await _show(
          baseTitle: 'اكتمل الرفع',
          body: snap.message,
          progress: 1,
          showProgress: false,
          ongoing: false,
        );
        Future.delayed(
          const Duration(seconds: 4),
          () => _plugin.cancel(_notificationId),
        );
      } else if (snap.status == UploadStatus.error) {
        await _show(
          baseTitle: 'فشل الرفع',
          body: snap.message,
          progress: 0,
          showProgress: false,
          ongoing: false,
        );
        Future.delayed(
          const Duration(seconds: 6),
          () => _plugin.cancel(_notificationId),
        );
      } else if (snap.status == UploadStatus.canceled) {
        await _show(
          baseTitle: 'تم إلغاء الرفع',
          body: snap.message,
          progress: 0,
          showProgress: false,
          ongoing: false,
        );
        Future.delayed(
          const Duration(seconds: 3),
          () => _plugin.cancel(_notificationId),
        );
      } else {
        await _plugin.cancel(_notificationId);
      }
      return;
    }

    final isPaused = snap.status == UploadStatus.paused;
    final title = isPaused ? 'موقوف مؤقتاً' : 'رفع الحلقات';
    final body = snap.message;
    await _show(
      baseTitle: title,
      body: body,
      progress: snap.overallProgress.clamp(0, 1),
      showProgress: true,
      ongoing: !isPaused,
      isPaused: isPaused,
    );
  }

  Future<void> _show({
    required String baseTitle,
    required String body,
    required double progress,
    required bool showProgress,
    required bool ongoing,
    bool isPaused = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      onlyAlertOnce: true,
      showProgress: showProgress,
      maxProgress: 1000,
      progress: (progress * 1000).round(),
      ongoing: ongoing,
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      actions: [
        AndroidNotificationAction(
          isPaused ? 'resume_upload' : 'pause_upload',
          isPaused ? 'استئناف' : 'إيقاف مؤقت',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'cancel_upload',
          'إلغاء',
          showsUserInterface: false,
        ),
      ],
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      _notificationId,
      baseTitle,
      body,
      details,
      payload: 'upload',
    );
  }

  Future<void> _onNotificationResponse(NotificationResponse resp) async {
    final actionId = resp.actionId;
    if (kDebugMode) debugPrint('Notification action: $actionId');
    if (actionId == 'pause_upload') {
      UploadManager.instance.pauseUpload();
    } else if (actionId == 'resume_upload') {
      UploadManager.instance.resumeUpload();
    } else if (actionId == 'cancel_upload') {
      UploadManager.instance.cancelUpload();
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse resp) {
  // Background tap handler for notification actions (Android)
  final id = resp.actionId;
  if (kDebugMode) debugPrint('Background notification action: $id');
  // NOTE: Cannot directly call singleton safely here without ensuring isolate; simplest: rely on foreground taps.
}
