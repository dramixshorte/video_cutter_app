import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_cutter_app/screens/AdmobSettingsTab.dart';
import 'package:video_cutter_app/screens/AppSettingsTab.dart';
import 'package:video_cutter_app/screens/CoinPackagesTab.dart';
import 'package:video_cutter_app/screens/DailyGiftsTab.dart';
import 'package:video_cutter_app/screens/UsersManagementTab.dart';
import 'package:video_cutter_app/screens/VipPackagesTab.dart';
import 'package:video_cutter_app/screens/VideoCutterScreen.dart';
import 'package:video_cutter_app/screens/SeriesDetailsScreen.dart';

class DashboardSettingsScreen extends StatefulWidget {
  const DashboardSettingsScreen({super.key});

  @override
  State<DashboardSettingsScreen> createState() =>
      _DashboardSettingsScreenState();
}

class _DashboardSettingsScreenState extends State<DashboardSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> _settingsOptions = [
    // إدارة المحتوى
    {
      'icon': Icons.movie_creation_rounded,
      'label': 'إدارة المسلسلات',
      'color': Color(0xFFE91E63),
      'type': 'series_management',
      'category': 'content',
      'description': 'إدارة المسلسلات والحلقات والمحتوى',
    },
    {
      'icon': Icons.video_library_rounded,
      'label': 'تقطيع الفيديو',
      'color': Color(0xFF9C27B0),
      'type': 'video_cutter',
      'category': 'content',
      'description': 'أدوات تقطيع ومعالجة الفيديو',
    },

    // الإعدادات المالية
    {
      'icon': Icons.monetization_on,
      'label': 'حزم العملات',
      'color': Colors.amber,
      'type': 'coins',
      'category': 'financial',
      'description': 'إدارة حزم العملات والأسعار',
    },
    {
      'icon': Icons.card_giftcard,
      'label': 'الهدايا اليومية',
      'color': Colors.orange,
      'type': 'gifts',
      'category': 'financial',
      'description': 'تكوين الهدايا والمكافآت اليومية',
    },
    {
      'icon': Icons.star,
      'label': 'حزم VIP',
      'color': Colors.purple,
      'type': 'vip',
      'category': 'financial',
      'description': 'إدارة الاشتراكات المميزة',
    },

    // إعدادات التطبيق
    {
      'icon': Icons.ad_units,
      'label': 'إعدادات AdMob',
      'color': Colors.green,
      'type': 'admob',
      'category': 'app_settings',
      'description': 'تكوين الإعلانات ومعرفات AdMob',
    },
    {
      'icon': Icons.settings,
      'label': 'إعدادات التطبيق',
      'color': Colors.teal,
      'type': 'app_settings',
      'category': 'app_settings',
      'description': 'الإعدادات العامة للتطبيق',
    },

    // إدارة المستخدمين
    {
      'icon': Icons.people,
      'label': 'المستخدمين',
      'color': Colors.blue,
      'type': 'users',
      'category': 'users',
      'description': 'إدارة المستخدمين والصلاحيات',
    },
  ];

  final Map<String, Map<String, dynamic>> _categories = {
    'content': {
      'title': 'إدارة المحتوى',
      'icon': Icons.movie_creation_rounded,
      'color': Color(0xFFE91E63),
      'gradient': [Color(0xFFE91E63), Color(0xFFAD1457)],
    },
    'financial': {
      'title': 'الإعدادات المالية',
      'icon': Icons.monetization_on,
      'color': Colors.amber,
      'gradient': [Colors.amber, Colors.orange],
    },
    'app_settings': {
      'title': 'إعدادات التطبيق',
      'icon': Icons.settings,
      'color': Colors.teal,
      'gradient': [Colors.teal, Colors.cyan],
    },
    'users': {
      'title': 'إدارة المستخدمين',
      'icon': Icons.people,
      'color': Colors.blue,
      'gradient': [Colors.blue, Colors.indigo],
    },
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToSection(String type) {
    Widget page;

    switch (type) {
      // إدارة المحتوى
      case 'series_management':
        page = const SeriesListScreen();
        break;
      case 'video_cutter':
        page = const VideoCutterScreen();
        break;

      // الإعدادات المالية
      case 'coins':
        page = const CoinPackagesTab();
        break;
      case 'gifts':
        page = const DailyGiftsTab();
        break;
      case 'vip':
        page = const VipPackagesTab();
        break;

      // إعدادات التطبيق (محمية بالقفل)
      case 'admob':
        page = const AdmobSettingsTab();
        break;
      case 'app_settings':
        page = const AppSettingsTab();
        break;

      // إدارة المستخدمين
      case 'users':
        page = const UsersManagementTab();
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'إعدادات لوحة التحكم',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E2E).withOpacity(0.9),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF3D3D5A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),
                    ..._categories.entries.map((categoryEntry) {
                      return Column(
                        children: [
                          _buildCategorySection(
                            categoryEntry.key,
                            categoryEntry.value,
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF4845D2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إعدادات متقدمة',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'لوحة التحكم الاحترافية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر القسم المناسب لإدارة التطبيق',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String categoryKey,
    Map<String, dynamic> categoryData,
  ) {
    final categoryOptions = _settingsOptions
        .where((option) => option['category'] == categoryKey)
        .toList();

    if (categoryOptions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: categoryData['gradient'] as List<Color>,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (categoryData['color'] as Color).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryData['icon'] as IconData,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryData['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${categoryOptions.length} خيار متاح',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Category Options
        ...categoryOptions.map((option) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToSection(option['type']),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (option['color'] as Color).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              (option['color'] as Color).withOpacity(0.2),
                              (option['color'] as Color).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (option['color'] as Color).withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          option['icon'] as IconData,
                          color: option['color'] as Color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['label'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              option['description'] as String,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withOpacity(0.6),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
