import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_cutter_app/widgets/app_toast.dart';
import '../widgets/AuthDialog.dart';

class AdmobSettingsTab extends StatefulWidget {
  const AdmobSettingsTab({super.key});

  @override
  _AdmobSettingsTabState createState() => _AdmobSettingsTabState();
}

class _AdmobSettingsTabState extends State<AdmobSettingsTab>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> _mohamedSettings = {};
  Map<String, dynamic> _rivoSettings = {};
  Map<String, dynamic> _mainSettings = {};

  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

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

  final List<Map<String, dynamic>> _basicAdTypes = [
    {
      'key': 'app_id',
      'title': 'معرف التطبيق',
      'description': 'معرف التطبيق الرئيسي في AdMob',
      'icon': Icons.app_settings_alt,
      'color': Color(0xFF6C63FF),
      'required': true,
    },
    {
      'key': 'banner',
      'title': 'بانر الإعلانات',
      'description': 'إعلانات البانر في أعلى وأسفل الشاشة',
      'icon': Icons.view_headline,
      'color': Color(0xFF795548),
      'required': false,
    },
    {
      'key': 'interstitial',
      'title': 'الإعلانات البينية',
      'description': 'الإعلانات التي تظهر بملء الشاشة',
      'icon': Icons.fullscreen,
      'color': Color(0xFFE91E63),
      'required': false,
    },
  ];

  final List<Map<String, dynamic>> _rewardedAdTypes = [
    {
      'key': 'rewarded1',
      'title': 'إعلان مكافآت 1',
      'description': 'إعلان المكافآت الأول للحصول على العملات',
      'icon': Icons.monetization_on,
      'color': Color(0xFF4CAF50),
      'coins': 50,
      'required': true,
    },
    {
      'key': 'rewarded2',
      'title': 'إعلان مكافآت 2',
      'description': 'إعلان المكافآت الثاني للحصول على عملات إضافية',
      'icon': Icons.add_circle,
      'color': Color(0xFFFF6B6B),
      'coins': 100,
      'required': false,
    },
    {
      'key': 'rewarded3',
      'title': 'إعلان مكافآت 3',
      'description': 'إعلان المكافآت الثالث لمضاعفة المكافأة اليومية',
      'icon': Icons.calendar_today,
      'color': Color(0xFFFFD700),
      'coins': 200,
      'required': false,
    },
    {
      'key': 'rewarded4',
      'title': 'إعلان مكافآت 4',
      'description': 'إعلان المكافآت الرابع للوصول المؤقت لمحتوى VIP',
      'icon': Icons.star,
      'color': Color(0xFF9C27B0),
      'coins': 0,
      'required': false,
    },
    {
      'key': 'rewarded5',
      'title': 'إعلان مكافآت 5',
      'description': 'إعلان المكافآت الخامس لتخطي أوقات الانتظار',
      'icon': Icons.fast_forward,
      'color': Color(0xFF00BCD4),
      'coins': 0,
      'required': false,
    },
    {
      'key': 'rewarded6',
      'title': 'إعلان مكافآت 6',
      'description': 'إعلان المكافآت السادس للحصول على حياة إضافية',
      'icon': Icons.favorite,
      'color': Color(0xFFE91E63),
      'coins': 0,
      'required': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _loadSettings();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
    } catch (e) {
      print('Error loading AdMob settings: $e');
      _showSnackBar('حدث خطأ أثناء التحميل ⚠️', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAppSettings(String appKey, int index) async {
    try {
      // إنشاء قائمة بأسماء الحقول المطلوبة فقط
      List<String> requiredFields = [
        ..._basicAdTypes.map((ad) => ad['key'].toString()),
        ..._rewardedAdTypes.map((ad) => ad['key'].toString()),
      ];

      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_admob'),
        body: jsonEncode({
          'action': 'get',
          'app': appKey,
          'fields': requiredFields, // إرسال قائمة بالحقول المطلوبة فقط
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        Map<String, dynamic> rawSettings = Map.from(data['data'] ?? {});

        // تصفية البيانات للحصول على الحقول المطلوبة فقط
        Map<String, dynamic> filteredSettings = {};

        for (var adType in [..._basicAdTypes, ..._rewardedAdTypes]) {
          filteredSettings[adType['key']] = rawSettings[adType['key']] ?? '';
        }

        print('Raw data keys count for $appKey: ${rawSettings.keys.length}');
        print(
          'Filtered data keys count for $appKey: ${filteredSettings.keys.length}',
        );

        switch (index) {
          case 0:
            _mohamedSettings = filteredSettings;
            break;
          case 1:
            _rivoSettings = filteredSettings;
            break;
          case 2:
            _mainSettings = filteredSettings;
            break;
        }
      }
    } catch (e) {
      print('Error loading $appKey settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      try {
        final response = await http.post(
          Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_admob'),
          body: jsonEncode({
            'action': 'update',
            'app': _currentAppKey,
            ..._currentSettings,
          }),
          headers: {'Content-Type': 'application/json'},
        );

        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSnackBar('تم حفظ إعدادات AdMob بنجاح! 🎯', Colors.green);
        } else {
          _showSnackBar('فشل في حفظ الإعدادات ❌', Colors.red);
        }
      } catch (e) {
        print('Error saving AdMob settings: $e');
        _showSnackBar('حدث خطأ أثناء الحفظ ⚠️', Colors.red);
      }

      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    AppToast.show(
      context,
      message,
      type: color == Colors.red ? ToastType.error : ToastType.success,
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

  Widget _buildSectionHeader(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: EdgeInsets.only(top: 20, bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdSettingCard(
    Map<String, dynamic> adType, {
    bool isRewarded = false,
  }) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (adType['required'] == true)
                      ? (adType['color'] as Color).withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                adType['color'],
                                (adType['color'] as Color).withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            adType['icon'],
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      adType['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (adType['required'] == true)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'مطلوب',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                adType['description'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                              if (isRewarded &&
                                  adType['coins'] != null &&
                                  adType['coins'] > 0)
                                Container(
                                  margin: EdgeInsets.only(top: 8),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFFD700).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.monetization_on,
                                        color: Color(0xFFFFD700),
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '${adType['coins']} عملة',
                                        style: TextStyle(
                                          color: Color(0xFFFFD700),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Status Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (_currentSettings[adType['key']]
                                        ?.toString()
                                        .isNotEmpty ==
                                    true)
                                ? const Color(0xFF4CAF50).withOpacity(0.2)
                                : const Color(0xFFFF5722).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (_currentSettings[adType['key']]
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                    ? Icons.check_circle
                                    : Icons.error,
                                color:
                                    (_currentSettings[adType['key']]
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFFF5722),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (_currentSettings[adType['key']]
                                            ?.toString()
                                            .isNotEmpty ==
                                        true)
                                    ? 'مفعل'
                                    : 'معطل',
                                style: TextStyle(
                                  color:
                                      (_currentSettings[adType['key']]
                                              ?.toString()
                                              .isNotEmpty ==
                                          true)
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFFF5722),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Input Field
                    TextFormField(
                      initialValue:
                          _currentSettings[adType['key']]?.toString() ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'معرف الوحدة الإعلانية',
                        hintText: 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx',
                        labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.code,
                          color: adType['color'],
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: adType['color'],
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (adType['required'] == true &&
                            (value == null || value.isEmpty)) {
                          return 'هذا الحقل مطلوب';
                        }
                        if (value != null && value.isNotEmpty) {
                          if (!value.startsWith('ca-app-pub-')) {
                            return 'يجب أن يبدأ المعرف بـ ca-app-pub-';
                          }
                        }
                        return null;
                      },
                      onSaved: (value) {
                        Map<String, dynamic> settings = Map.from(
                          _currentSettings,
                        );
                        settings[adType['key']] = value ?? '';
                        _setCurrentSettings(settings);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF3D3D5A)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'جاري تحميل إعدادات AdMob...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF3D3D5A)],
          ),
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.only(
                top: 50,
                left: 30,
                right: 20,
                bottom: 50,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 24,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إعدادات AdMob المتقدمة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'إدارة معرفات الوحدات الإعلانية (${_rewardedAdTypes.length} إعلان مكافآت)',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // App Selector
            _buildAppSelector(),
            SizedBox(height: 10),

            // Content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Basic Ad Types Section
                      _buildSectionHeader(
                        'الإعدادات الأساسية',
                        'معرف التطبيق والإعلانات الأساسية',
                        Icons.settings,
                        Color(0xFF6C63FF),
                      ),
                      ...(_basicAdTypes.map(
                        (adType) => _buildAdSettingCard(adType),
                      )),

                      // Rewarded Ad Types Section
                      _buildSectionHeader(
                        'إعلانات المكافآت المتقدمة',
                        '${_rewardedAdTypes.length} إعلان مكافآت مختلف',
                        Icons.card_giftcard,
                        Color(0xFF4CAF50),
                      ),
                      ...(_rewardedAdTypes.map(
                        (adType) =>
                            _buildAdSettingCard(adType, isRewarded: true),
                      )),

                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Save Button
            Container(
              padding: const EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: 60,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _apps[_selectedAppIndex]['color'],
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: (_apps[_selectedAppIndex]['color'] as Color)
                        .withOpacity(0.4),
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
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
                            const Icon(
                              Icons.save,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'حفظ إعدادات ${_apps[_selectedAppIndex]['name']}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
