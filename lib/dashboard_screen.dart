import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:video_cutter_app/screens/AdmobSettingsTab.dart';
import 'package:video_cutter_app/screens/AppSettingsTab.dart';
import 'package:video_cutter_app/screens/CoinPackagesTab.dart';
import 'package:video_cutter_app/screens/DailyGiftsTab.dart';
import 'package:video_cutter_app/screens/UsersManagementTab.dart';
import 'package:video_cutter_app/screens/VipPackagesTab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTab = 0;
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  final List<Map<String, dynamic>> _dashboardTabs = [
    {'icon': Icons.analytics, 'label': 'الإحصائيات'},
    {'icon': Icons.settings, 'label': 'إعدادات AdMob'},
    {'icon': Icons.monetization_on, 'label': 'حزم العملات'},
    {'icon': Icons.card_giftcard, 'label': 'الهدايا اليومية'},
    {'icon': Icons.person, 'label': 'المستخدمين'},
    {'icon': Icons.star, 'label': 'حزم VIP'},
    {'icon': Icons.settings_applications, 'label': 'إعدادات التطبيق'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=get_dashboard_stats',
        ),
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _stats = data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading stats: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatsTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
            SizedBox(height: 16),
            Text(
              'جاري تحميل الإحصائيات...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1E2E),
            Color(0xFF2D2D44),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'نظرة عامة على الإحصائيات',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.10,
              children: [
                _StatCard(
                  title: 'إجمالي المسلسلات',
                  value: _stats['total_series']?.toString() ?? '0',
                  icon: Icons.movie_creation,
                  gradient: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
                ),
                _StatCard(
                  title: 'إجمالي الحلقات',
                  value: _stats['total_episodes']?.toString() ?? '0',
                  icon: Icons.video_library,
                  gradient: [Color(0xFF4CC9F0), Color(0xFF4895EF)],
                ),
                _StatCard(
                  title: 'إجمالي المستخدمين',
                  value: _stats['total_users']?.toString() ?? '0',
                  icon: Icons.people_alt,
                  gradient: [Color(0xFFFF9E01), Color(0xFFFF7700)],
                ),
                _StatCard(
                  title: 'إجمالي العملات',
                  value: _stats['total_coins']?.toString() ?? '0',
                  icon: Icons.monetization_on,
                  gradient: [Color(0xFFF9C74F), Color(0xFFF8961E)],
                ),
                _StatCard(
                  title: 'المعاملات اليوم',
                  value: _stats['today_transactions']?.toString() ?? '0',
                  icon: Icons.swap_horiz,
                  gradient: [Color(0xFF7209B7), Color(0xFF560BAD)],
                ),
                _StatCard(
                  title: 'المشاهدات اليوم',
                  value: _stats['today_views']?.toString() ?? '0',
                  icon: Icons.remove_red_eye,
                  gradient: [Color(0xFFF94144), Color(0xFFF3722C)],
                ),
              ],
            ),
            SizedBox(height: 24),
            if (_stats.isNotEmpty) ...[
              Text(
                'إحصائيات إضافية',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _StatRow(
                      label: 'المستخدمين النشطين اليوم',
                      value: _stats['active_users_today']?.toString() ?? '0',
                    ),
                    Divider(color: Colors.white12),
                    _StatRow(
                      label: 'إجمالي الإيرادات',
                      value: '${_stats['total_revenue']?.toString() ?? '0'} \$',
                    ),
                    Divider(color: Colors.white12),
                    _StatRow(
                      label: 'متوسط المشاهدات اليومية',
                      value: _stats['avg_daily_views']?.toString() ?? '0',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdmobSettings() {
    return AdmobSettingsTab();
  }

  Widget _buildCoinPackages() {
    return CoinPackagesTab();
  }

  Widget _buildDailyGifts() {
    return DailyGiftsTab();
  }

  Widget _buildUsersManagement() {
    return UsersManagementTab();
  }

  Widget _buildVipPackages() {
    return VipPackagesTab();
  }

  Widget _buildAppSettings() {
    return AppSettingsTab();
  }

  Widget _buildCurrentTab() {
    switch (_selectedTab) {
      case 0:
        return _buildStatsTab();
      case 1:
        return _buildAdmobSettings();
      case 2:
        return _buildCoinPackages();
      case 3:
        return _buildDailyGifts();
      case 4:
        return _buildUsersManagement();
      case 5:
        return _buildVipPackages();
      case 6:
        return _buildAppSettings();
      default:
        return Center(
          child: Text(
            'شاشة قيد التطوير',
            style: TextStyle(color: Colors.white70),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة التحكم',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Color(0xFF1E1E2E),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Color(0xFF1E1E2E),
          statusBarIconBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      backgroundColor: Color(0xFF1E1E2E),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFF2D2D44),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _dashboardTabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  return _DashboardTab(
                    icon: tab['icon'],
                    label: tab['label'],
                    isSelected: _selectedTab == index,
                    onTap: () => setState(() => _selectedTab = index),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(child: _buildCurrentTab()),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DashboardTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.white30, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}