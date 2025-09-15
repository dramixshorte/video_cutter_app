
// إعدادات التطبيق
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AppSettingsTab extends StatefulWidget {
  const AppSettingsTab({super.key});

  @override
  
  
  _AppSettingsTabState createState() => _AppSettingsTabState();
}

class _AppSettingsTabState extends State<AppSettingsTab> {
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
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_app_settings',
        ),
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
          Uri.parse(
            'https://dramaxbox.bbs.tr/App/api.php?action=manage_app_settings',
          ),
          body: jsonEncode({'action': 'update', ..._settings}),
          headers: {'Content-Type': 'application/json'},
        );

        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('تم حفظ الإعدادات بنجاح')));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('فشل في حفظ الإعدادات')));
        }
      } catch (e) {
        print('Error saving settings: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحفظ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إعدادات التطبيق',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildTextField(
              'اسم الموقع',
              'site_name',
              initialValue: _settings['site_name'] ?? '',
            ),
            _buildTextField(
              'بريد الموقع',
              'site_email',
              initialValue: _settings['site_email'] ?? '',
            ),
            _buildTextField(
              'وصف الموقع',
              'site_description',
              initialValue: _settings['site_description'] ?? '',
              maxLines: 3,
            ),
            _buildNumberField(
              'عدد العناصر في الصفحة',
              'items_per_page',
              initialValue: _settings['items_per_page']?.toString() ?? '20',
            ),
            _buildNumberField(
              'سعر الحلقة',
              'episode_price',
              initialValue: _settings['episode_price']?.toString() ?? '10',
            ),
            SizedBox(height: 16),
            Text('وضع التطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField(
              value: _settings['app_mode']?.toString(),
              items: [
                DropdownMenuItem(value: '0', child: Text('وضع عادي')),
                DropdownMenuItem(value: '1', child: Text('وضع صيانة')),
                DropdownMenuItem(
                  value: '3',
                  child: Text('وضع التحديث الإجباري'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _settings['app_mode'] = int.parse(value!);
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: Text('حفظ الإعدادات', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color.fromARGB(255, 0, 0, 0),
        ),
        maxLines: maxLines,
        onSaved: (value) => _settings[field] = value,
      ),
    );
  }

  Widget _buildNumberField(String label, String field, {String? initialValue}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color.fromARGB(255, 0, 0, 0),
        ),
        keyboardType: TextInputType.number,
        onSaved: (value) => _settings[field] = int.parse(value!),
      ),
    );
  }
}
