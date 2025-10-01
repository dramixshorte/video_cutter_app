import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'upload_manager.dart';

/// IDs & channel configuration
class UploadNotificationService {
  static final UploadNotificationService instance =
      UploadNotificationService._();
  UploadNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription? _sub;
  static const _methodChannel = MethodChannel('upload_foreground_channel');

  static const _channelId = 'upload_progress_channel';
  static const _channelName = 'رفع الحلقات';
  static const _channelDesc =
      'إشعار مستمر يوضح تقدم رفع الحلقات مع تحكم بالإيقاف المؤقت والاستئناف.';

  Future<void> init() async {
    if (_initialized) return;
    if (kDebugMode) debugPrint('[UploadNotif] init start');
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    // Listen for native action callbacks (pause/resume/cancel)
    _methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'nativePause':
          UploadManager.instance.pauseUpload();
          break;
        case 'nativeResume':
          UploadManager.instance.resumeUpload();
          break;
        case 'nativeCancel':
          UploadManager.instance.cancelUpload();
          break;
        case 'nativeClean':
          // Trigger cleanup of any local temp episodes
          UploadManager.instance.cleanLocalEpisodes();
          break;
        case 'nativeToggle':
          final collapsed = (call.arguments as Map?)?['collapsed'] == true;
          _collapsed = collapsed;
          break;
        case 'nativeHide':
          // User hid notification; keep foreground maybe stopped if no active upload
          break;
      }
    });
    // Create channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.low,
      showBadge: false,
      enableVibration: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _initialized = true;
    if (kDebugMode) debugPrint('[UploadNotif] channel created & initialized');
    _bindStream();
  }

  void _bindStream() {
    _sub?.cancel();
    _sub = UploadManager.instance.stream.listen(_onUploadUpdate);
  }

  bool _collapsed = false;
  bool _foregroundStarted =
      false; // ensure startForeground called only once per active session

  Future<void> _onUploadUpdate(UploadProgressSnapshot snap) async {
    if (!_initialized) return;
    if (kDebugMode) {
      debugPrint(
        '[UploadNotif] snapshot status=${snap.status} overall=${snap.overallProgress} ep=${snap.currentEpisodeProgress}',
      );
    }
    if (snap.status == UploadStatus.idle) {
      if (_foregroundStarted) {
        try {
          await _methodChannel.invokeMethod('stopForeground');
        } catch (_) {}
        _foregroundStarted = false;
      }
      return;
    }
    if (snap.status == UploadStatus.completed ||
        snap.status == UploadStatus.error ||
        snap.status == UploadStatus.canceled) {
      // Let native side show final (we can also send a last update with status)
      try {
        await _methodChannel.invokeMethod('updateForegroundFull', {
          'title': (snap.status == UploadStatus.completed)
              ? 'اكتمل الرفع'
              : (snap.status == UploadStatus.error
                    ? 'فشل الرفع'
                    : 'تم إلغاء الرفع'),
          'message': snap.message,
          'overallProgress': (snap.overallProgress * 100).round(),
          'episodeProgress': (snap.currentEpisodeProgress * 100).round(),
          'episodeIndex': snap.currentEpisodeNumber,
          'totalEpisodes': snap.totalEpisodes,
          'status': _mapStatus(snap.status),
          'paused': false,
          'hasLocalEpisodes': snap.totalEpisodes > 0,
          'collapsed': _collapsed,
        });
      } catch (_) {}
      // Optionally stop after short delay
      Future.delayed(const Duration(seconds: 5), () async {
        if (_foregroundStarted) {
          try {
            await _methodChannel.invokeMethod('stopForeground');
          } catch (_) {}
          _foregroundStarted = false;
        }
      });
      return;
    }

    final isPaused = snap.status == UploadStatus.paused;
    final titleBase = isPaused ? 'موقوف مؤقتاً' : 'رفع الحلقات';
    // Smooth overall: base overallProgress (completed episodes fraction) + current partial
    double smoothOverall = snap.overallProgress;
    if (snap.status == UploadStatus.uploadingEpisodes &&
        snap.totalEpisodes > 0 &&
        snap.currentEpisodeNumber > 0) {
      final perEpisode = 1.0 / snap.totalEpisodes;
      // overallProgress already counts fully finished episodes (uploaded variable in manager)
      // Add current partial minus any double count: if overallProgress already includes only finished episodes, safe to add.
      final finishedFraction =
          snap.overallProgress; // episodes fully done / total
      final partial = snap.currentEpisodeProgress * perEpisode;
      smoothOverall = (finishedFraction + partial).clamp(0.0, 1.0);
    }
    final overallPct = (smoothOverall * 100).clamp(0, 100).toStringAsFixed(0);
    final episodeLine =
        (snap.status == UploadStatus.uploadingEpisodes &&
            snap.totalEpisodes > 0)
        ? 'الحلقة ${snap.currentEpisodeNumber}/${snap.totalEpisodes} (${(snap.currentEpisodeProgress * 100).clamp(0, 100).toStringAsFixed(0)}%)'
        : '';
    final body = [
      snap.message,
      episodeLine,
    ].where((e) => e.isNotEmpty).join('\n');
    final title = '$titleBase – $overallPct%';
    // Ensure foreground service is running & update native notification (placeholder until RemoteViews phase)
    try {
      // Start service once
      if (!_foregroundStarted) {
        // Set flag first to prevent re-entrancy if another snapshot lands while awaiting native call
        _foregroundStarted = true;
        await _methodChannel.invokeMethod('startForeground', {
          'title': title,
          'text': body,
        });
        if (kDebugMode) debugPrint('[UploadNotif] startForeground sent');
      }
      await _methodChannel.invokeMethod('updateForegroundFull', {
        'title': title,
        'message': snap.message,
        'overallProgress': (smoothOverall * 100).round(),
        'episodeProgress': (snap.currentEpisodeProgress * 100).round(),
        'episodeIndex': snap.currentEpisodeNumber,
        'totalEpisodes': snap.totalEpisodes,
        'status': _mapStatus(snap.status),
        'paused': isPaused,
        'hasLocalEpisodes': snap.totalEpisodes > 0,
        'collapsed': _collapsed,
      });
      if (kDebugMode) debugPrint('[UploadNotif] updateForegroundFull sent');
    } catch (err) {
      if (kDebugMode) debugPrint('[UploadNotif] native update failed: $err');
      /* native path failed - still show plugin notification */
    }
    // تم إلغاء إشعار Flutter المؤقت (fallback) للاعتماد على إشعار الخدمة المخصص فقط.
  }

  String _mapStatus(UploadStatus status) {
    switch (status) {
      case UploadStatus.paused:
        return 'paused';
      case UploadStatus.completed:
        return 'completed';
      case UploadStatus.error:
        return 'error';
      default:
        return 'running';
    }
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
