import 'package:flutter/material.dart';
import 'dart:async'; // runZonedGuarded
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'dashboard_screen.dart';
import 'screens/VideoCutterScreen.dart';
import 'services/upload_notification_service.dart';
import 'screens/series_list_screen.dart';
import 'widgets/global_upload_panel.dart';
import 'screens/DashboardSettingsScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // التقاط جميع الأخطاء غير المعالجة لمنع إغلاق التطبيق فجأة
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: \\n${details.exceptionAsString()}');
  };

  // (اختياري) يمكن إضافة معالج أخطاء عام لاحقاً إذا لزم

  try {
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

    print('بدء تهيئة التطبيق...');
    // تهيئة إشعارات الرفع (قناة، متابعة التقدم، أزرار الإيقاف والاستئناف)
    await UploadNotificationService.instance.init();
  } catch (e) {
    print('خطأ في التهيئة الأساسية: $e');
  }

  // تهيئة خدمة الرفع في الخلفية + مدير التقدم

  runApp(const RootApp());
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

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DramaXBox - Admin Panel',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      ),
      home: const BottomRoot(),
    );
  }
}

class BottomRoot extends StatefulWidget {
  const BottomRoot({super.key});
  @override
  State<BottomRoot> createState() => _BottomRootState();
}

class _BottomRootState extends State<BottomRoot> {
  int _index = 0;
  late final List<Widget> _pages = [
    const VideoCutterScreen(),
    const SeriesListScreen(),
    const DashboardScreen(),
    const DashboardSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Use IndexedStack to keep state of all tabs and ensure proper rendering
          IndexedStack(index: _index, children: _pages),
          // Overlay upload panel; IgnorePointer prevents intercepting taps when hidden
          const GlobalUploadPanel(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 65,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.cut), label: 'التقطيع'),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            label: 'المسلسلات',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'لوحة التحكم',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

// Placeholder removed; real SeriesListScreen implemented.
