
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:video_cutter_app/screens/VideoCutterApp.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "جاري رفع الحلقات",
    notificationText: "التطبيق يعمل في الخلفية",
    notificationImportance: AndroidNotificationImportance.high,
  );

  final hasPermissions = await FlutterBackground.initialize(
    androidConfig: androidConfig,
  );

  if (hasPermissions) {
    await FlutterBackground.enableBackgroundExecution();
  }
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await WakelockPlus.enable();

  runApp(const VideoCutterApp());
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'upload_episode_task':
        break;
      case 'show_upload_complete_notification':
        break;
      case 'show_upload_failed_notification':
        break;
    }
    return true;
  });
}







