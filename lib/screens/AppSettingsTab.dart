import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/AuthDialog.dart';

class AppSettingsTab extends StatefulWidget {
  const AppSettingsTab({super.key});

  @override
  _AppSettingsTabState createState() => _AppSettingsTabState();
}

class _AppSettingsTabState extends State<AppSettingsTab>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> _mohamedSettings = {};
  Map<String, dynamic> _rivoSettings = {};
  Map<String, dynamic> _mainSettings = {};

  bool _isLoading = true;
  bool _isSaving = false;

  late AnimationController _animationController;
  late AnimationController _saveButtonController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  int _selectedAppIndex = 0; // 0: محمد، 1: ريفو، 2: أساسي

  final List<Map<String, dynamic>> _apps = [
    {
      'name': 'محمد',
      'key': 'mohamed',
      'color': Color(0xFF4CAF50),
      'icon': Icons.person,
    },
    {
      'name': 'تطبيق ريفو شورت',
      'key': 'rivo',
      'color': Color(0xFFFF9800),
      'icon': Icons.movie,
    },
    {
      'name': 'التطبيق الأساسي',
      'key': 'main',
      'color': Color(0xFF2196F3),
      'icon': Icons.apps,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _saveButtonController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.elasticOut),
    );

    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _currentSettings {
    switch (_selectedAppIndex) {
      case 0:
        return _mohamedSettings;
      case 1:
        return _rivoSettings;
      case 2:
        return _mainSettings;
      default:
        return _mohamedSettings;
    }
  }

  void _setCurrentSettings(Map<String, dynamic> settings) {
    switch (_selectedAppIndex) {
      case 0:
        _mohamedSettings = settings;
        break;
      case 1:
        _rivoSettings = settings;
        break;
      case 2:
        _mainSettings = settings;
        break;
    }
  }

  String get _currentAppKey {
    return _apps[_selectedAppIndex]['key'];
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // تحميل إعدادات محمد
      await _loadAppSettings('mohamed', 0);
      // تحميل إعدادات ريفو
      await _loadAppSettings('rivo', 1);
      // تحميل إعدادات التطبيق الأساسي
      await _loadAppSettings('main', 2);

      setState(() => _isLoading = false);
      _animationController.forward();
      _saveButtonController.forward();
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('خطأ في تحميل إعدادات التطبيق');
    }
  }

  Future<void> _loadAppSettings(String appKey, int index) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_app_settings',
        ),
        body: jsonEncode({'action': 'get', 'app': appKey}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        Map<String, dynamic> settings = Map.from(data['data'] ?? {});
        // إضافة القيم الافتراضية
        settings['app_mode'] = settings['app_mode'] ?? '1';
        settings['free_mode_ads'] = settings['free_mode_ads'] ?? '1';
        settings['site_name'] =
            settings['site_name'] ?? _getDefaultSiteName(appKey);
        settings['site_email'] =
            settings['site_email'] ?? 'admin@dramixshrt.com';
        settings['site_description'] =
            settings['site_description'] ?? _getDefaultDescription(appKey);
        settings['items_per_page'] = settings['items_per_page'] ?? '20';
        settings['episode_price'] = settings['episode_price'] ?? '10';

        switch (index) {
          case 0:
            _mohamedSettings = settings;
            break;
          case 1:
            _rivoSettings = settings;
            break;
          case 2:
            _mainSettings = settings;
            break;
        }
      }
    } catch (e) {
      print('Error loading $appKey settings: $e');
    }
  }

  String _getDefaultSiteName(String appKey) {
    switch (appKey) {
      case 'mohamed':
        return 'محمد';
      case 'rivo':
        return 'ريفو شورت';
      case 'main':
        return 'DramaXBox';
      default:
        return 'تطبيق';
    }
  }

  String _getDefaultDescription(String appKey) {
    switch (appKey) {
      case 'mohamed':
        return 'تطبيق محمد للمسلسلات والأفلام';
      case 'rivo':
        return 'ريفو شورت - أفضل منصة للفيديوهات القصيرة';
      case 'main':
        return 'منصة مسلسلات متقدمة';
      default:
        return 'منصة ترفيهية';
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      try {
        final response = await http.post(
          Uri.parse(
            'https://dramaxbox.bbs.tr/App/api.php?action=manage_app_settings',
          ),
          body: jsonEncode({
            'action': 'update',
            'app': _currentAppKey,
            ..._currentSettings,
          }),
          headers: {'Content-Type': 'application/json'},
        );

        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessSnackBar(
            'تم حفظ إعدادات ${_apps[_selectedAppIndex]['name']} بنجاح',
          );
        } else {
          _showErrorSnackBar(data['message'] ?? 'فشل في حفظ الإعدادات');
        }
      } catch (e) {
        print('Error saving settings: $e');
        _showErrorSnackBar('حدث خطأ أثناء الحفظ');
      }

      setState(() => _isSaving = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildAppSelector() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: _apps.asMap().entries.map((entry) {
          final index = entry.key;
          final app = entry.value;
          final isSelected = index == _selectedAppIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () async {
                // القفل للتطبيقات المحمية (ريفو والأساسي فقط)
                if (index == 1 || index == 2) {
                  // ريفو أو أساسي
                  final authenticated = await AuthDialog.showPasswordDialog(
                    context,
                  );
                  if (!authenticated) {
                    return; // لا نتابع إذا لم يتم التوثيق
                  }
                }
                setState(() => _selectedAppIndex = index);
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            app['color'],
                            (app['color'] as Color).withOpacity(0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (app['color'] as Color).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      app['icon'],
                      color: isSelected ? Colors.white : Colors.white60,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        app['name'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF1E1E2E)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'جاري تحميل إعدادات التطبيقات...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'يرجى الانتظار',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF1E1E2E)],
          ),
        ),
        child: Column(
          children: [
            // Header Section
            _buildHeaderSection(),

            // App Selector
            SizedBox(height: 20),
            _buildAppSelector(),
            SizedBox(height: 20),

            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // App Mode Settings Card
                          _buildAppModeCard(),
                          SizedBox(height: 20),

                          // General Settings Card
                          _buildGeneralSettingsCard(),
                          SizedBox(height: 20),

                          // Site Information Card
                          _buildSiteInfoCard(),
                          SizedBox(height: 32),

                          // Save Button
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: _buildSaveButton(),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    Color currentColor = _apps[_selectedAppIndex]['color'];

    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            currentColor.withOpacity(0.1),
            currentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon with animated container
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [currentColor, currentColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: currentColor.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.settings_applications,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(width: 20),

          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات ${_apps[_selectedAppIndex]['name']}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'تخصيص إعدادات وأوضاع التشغيل',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
                SizedBox(height: 12),

                // Settings counter
                Row(
                  children: [
                    _buildStatItem(
                      icon: Icons.tune,
                      label: 'الإعدادات',
                      value: '${_currentSettings.length}',
                      color: currentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Settings icon
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: currentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: currentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              _apps[_selectedAppIndex]['icon'],
              color: currentColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildAppModeCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.app_settings_alt,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'أوضاع التطبيق',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // App Mode Switch
          _buildModeSwitchCard(
            title: 'وضع التطبيق',
            subtitle: 'اختر وضع التطبيق (مجاني أو مدفوع)',
            value: (_currentSettings['app_mode'] ?? 1) == 1,
            onChanged: (bool value) {
              setState(() {
                Map<String, dynamic> settings = Map.from(_currentSettings);
                settings['app_mode'] = value ? 1 : 0;
                _setCurrentSettings(settings);
              });
            },
            enabledLabel: 'مدفوع',
            disabledLabel: 'مجاني',
            enabledIcon: Icons.lock,
            disabledIcon: Icons.lock_open,
            enabledColor: Color(0xFF4CAF50),
            disabledColor: Color(0xFFFF9800),
          ),

          SizedBox(height: 16),

          // Free Mode Ads Switch
          _buildModeSwitchCard(
            title: 'إعلانات الوضع المجاني',
            subtitle: 'تفعيل الإعلانات في الوضع المجاني',
            value: (_currentSettings['free_mode_ads'] ?? 1) == 1,
            onChanged: (bool value) {
              setState(() {
                Map<String, dynamic> settings = Map.from(_currentSettings);
                settings['free_mode_ads'] = value ? 1 : 0;
                _setCurrentSettings(settings);
              });
            },
            enabledLabel: 'مفعل',
            disabledLabel: 'معطل',
            enabledIcon: Icons.ads_click,
            disabledIcon: Icons.block,
            enabledColor: Color(0xFF2196F3),
            disabledColor: Color(0xFFE53E3E),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required String enabledLabel,
    required String disabledLabel,
    required IconData enabledIcon,
    required IconData disabledIcon,
    required Color enabledColor,
    required Color disabledColor,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? enabledColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (value ? enabledColor : disabledColor).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              value ? enabledIcon : disabledIcon,
              color: value ? enabledColor : disabledColor,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Column(
            children: [
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: enabledColor,
                inactiveThumbColor: disabledColor,
                inactiveTrackColor: disabledColor.withOpacity(0.3),
              ),
              Text(
                value ? enabledLabel : disabledLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: value ? enabledColor : disabledColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettingsCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune, color: Color(0xFF2196F3), size: 24),
              ),
              SizedBox(width: 16),
              Text(
                'الإعدادات العامة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _buildNumberField(
            'عدد العناصر في الصفحة',
            'items_per_page',
            initialValue:
                _currentSettings['items_per_page']?.toString() ?? '20',
            icon: Icons.format_list_numbered,
            hint: 'أدخل عدد العناصر (مثال: 20)',
          ),
          _buildNumberField(
            'سعر الحلقة (بالعملات)',
            'episode_price',
            initialValue: _currentSettings['episode_price']?.toString() ?? '10',
            icon: Icons.attach_money,
            hint: 'أدخل سعر الحلقة (مثال: 10)',
          ),
        ],
      ),
    );
  }

  Widget _buildSiteInfoCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFF9800).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info, color: Color(0xFFFF9800), size: 24),
              ),
              SizedBox(width: 16),
              Text(
                'معلومات التطبيق',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _buildTextField(
            'اسم التطبيق',
            'site_name',
            initialValue: _currentSettings['site_name'] ?? '',
            icon: Icons.title,
            hint: 'أدخل اسم التطبيق',
          ),
          _buildTextField(
            'بريد التطبيق',
            'site_email',
            initialValue: _currentSettings['site_email'] ?? '',
            icon: Icons.email,
            hint: 'أدخل البريد الإلكتروني',
          ),
          _buildTextField(
            'وصف التطبيق',
            'site_description',
            initialValue: _currentSettings['site_description'] ?? '',
            maxLines: 3,
            icon: Icons.description,
            hint: 'أدخل وصف التطبيق والخدمات المقدمة',
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    Color currentColor = _apps[_selectedAppIndex]['color'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isSaving
              ? [Color(0x000ff666), Color(0x000ff444)]
              : [currentColor, currentColor.withOpacity(0.7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: currentColor.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'جاري الحفظ...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'حفظ إعدادات ${_apps[_selectedAppIndex]['name']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String field, {
    String? initialValue,
    int maxLines = 1,
    IconData? icon,
    String? hint,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue,
        style: TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: icon != null
              ? Container(
                  margin: EdgeInsets.all(8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF667eea).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Color(0xFF667eea), size: 20),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color(0xFF667eea), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        maxLines: maxLines,
        onSaved: (value) {
          Map<String, dynamic> settings = Map.from(_currentSettings);
          settings[field] = value ?? '';
          _setCurrentSettings(settings);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildNumberField(
    String label,
    String field, {
    String? initialValue,
    IconData? icon,
    String? hint,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue == '0' ? '' : initialValue,
        style: TextStyle(color: Colors.white, fontSize: 16),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: icon != null
              ? Container(
                  margin: EdgeInsets.all(8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Color(0xFF2196F3), size: 20),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onSaved: (value) {
          Map<String, dynamic> settings = Map.from(_currentSettings);
          settings[field] = int.tryParse(value ?? '0') ?? 0;
          _setCurrentSettings(settings);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          if (int.tryParse(value) == null) {
            return 'يرجى إدخال رقم صحيح';
          }
          return null;
        },
      ),
    );
  }
}
