import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تمكين العرض من الحافة إلى الحافة لـ Android 15
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // إعدادات نمط النظام للتوافق مع Android 15
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

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
    }
    return Future.value(true);
  });
}

class VideoCutterApp extends StatelessWidget {
  const VideoCutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DramaXBox - Admin Panel',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E2E),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
