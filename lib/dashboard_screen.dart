import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=get_dashboard_stats'),
      );
      
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _stats = data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _StatCard(
            title: 'إجمالي المسلسلات',
            value: _stats['total_series']?.toString() ?? '0',
            icon: Icons.movie,
            color: Colors.blue,
          ),
          _StatCard(
            title: 'إجمالي الحلقات',
            value: _stats['total_episodes']?.toString() ?? '0',
            icon: Icons.video_library,
            color: Colors.green,
          ),
          _StatCard(
            title: 'إجمالي المستخدمين',
            value: _stats['total_users']?.toString() ?? '0',
            icon: Icons.people,
            color: Colors.orange,
          ),
          _StatCard(
            title: 'إجمالي العملات',
            value: _stats['total_coins']?.toString() ?? '0',
            icon: Icons.monetization_on,
            color: Colors.amber,
          ),
          _StatCard(
            title: 'المعاملات اليوم',
            value: _stats['today_transactions']?.toString() ?? '0',
            icon: Icons.swap_horiz,
            color: Colors.purple,
          ),
          _StatCard(
            title: 'المشاهدات اليوم',
            value: _stats['today_views']?.toString() ?? '0',
            icon: Icons.remove_red_eye,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildAdmobSettings() {
    return Center(child: Text('شاشة إعدادات AdMob - قيد التطوير'));
  }

  Widget _buildCurrentTab() {
    switch (_selectedTab) {
      case 0: return _buildStatsTab();
      case 1: return _buildAdmobSettings();
      // ... باقي التبويبات
      default: return Center(child: Text('شاشة قيد التطوير'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة التحكم'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          SingleChildScrollView(
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[700]),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
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
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 40, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }
}