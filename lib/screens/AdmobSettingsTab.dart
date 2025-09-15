// ignore: file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdmobSettingsTab extends StatefulWidget {
  const AdmobSettingsTab({super.key});

  @override
  _AdmobSettingsTabState createState() => _AdmobSettingsTabState();
}

class _AdmobSettingsTabState extends State<AdmobSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_admob'),
        body: jsonEncode({'action': 'get'}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _settings = data['data'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final response = await http.post(
          Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_admob'),
          body: jsonEncode({'action': 'update', ..._settings}),
          headers: {'Content-Type': 'application/json'},
        );

        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ إعدادات AdMob بنجاح'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            )
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في حفظ الإعدادات'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            )
          );
        }
      } catch (e) {
        print('Error saving settings: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'جاري تحميل إعدادات AdMob...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF6C63FF), width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'إعدادات AdMob',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Card(
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white.withOpacity(0.05),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المعلومات الأساسية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          'معرف التطبيق',
                          'app_id',
                          initialValue: _settings['app_id'] ?? '',
                          icon: Icons.apps,
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white.withOpacity(0.05),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إعلانات البانر',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          'إعلان البانر',
                          'banner',
                          initialValue: _settings['banner'] ?? '',
                          icon: Icons.view_agenda,
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white.withOpacity(0.05),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الإعلانات Interstitial',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          'إعلان Interstitial',
                          'interstitial',
                          initialValue: _settings['interstitial'] ?? '',
                          icon: Icons.fullscreen,
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white.withOpacity(0.05),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الإعلانات المكافأة (Rewarded)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildTextField(
                          'إعلان Rewarded 1',
                          'rewarded1',
                          initialValue: _settings['rewarded1'] ?? '',
                          icon: Icons.videogame_asset,
                        ),
                        _buildTextField(
                          'إعلان Rewarded 2',
                          'rewarded2',
                          initialValue: _settings['rewarded2'] ?? '',
                          icon: Icons.videogame_asset,
                        ),
                        _buildTextField(
                          'إعلان Rewarded 3',
                          'rewarded3',
                          initialValue: _settings['rewarded3'] ?? '',
                          icon: Icons.videogame_asset,
                        ),
                        _buildTextField(
                          'إعلان Rewarded 4',
                          'rewarded4',
                          initialValue: _settings['rewarded4'] ?? '',
                          icon: Icons.videogame_asset,
                        ),
                        _buildTextField(
                          'إعلان Rewarded 5',
                          'rewarded5',
                          initialValue: _settings['rewarded5'] ?? '',
                          icon: Icons.videogame_asset,
                        ),
                        _buildTextField(
                          'إعلان Rewarded 6',
                          'rewarded6',
                          initialValue: _settings['rewarded6'] ?? '',
                          icon: Icons.videogame_asset,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Center(
                  child: Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6C63FF),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: Color(0xFF6C63FF).withOpacity(0.4),
                      ),
                      child: Text(
                        'حفظ إعدادات AdMob',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String field, {String? initialValue, IconData? icon}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
        ),
        onSaved: (value) => _settings[field] = value,
      ),
    );
  }
}