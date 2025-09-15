
// إعدادات AdMob
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdmobSettingsTab extends StatefulWidget {
  const AdmobSettingsTab({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
              'إعدادات AdMob',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildTextField(
              'معرف التطبيق',
              'app_id',
              initialValue: _settings['app_id'] ?? '',
            ),
            _buildTextField(
              'إعلان البانر',
              'banner',
              initialValue: _settings['banner'] ?? '',
            ),
            _buildTextField(
              'إعلان Interstitial',
              'interstitial',
              initialValue: _settings['interstitial'] ?? '',
            ),
            _buildTextField(
              'إعلان Rewarded 1',
              'rewarded1',
              initialValue: _settings['rewarded1'] ?? '',
            ),
            _buildTextField(
              'إعلان Rewarded 2',
              'rewarded2',
              initialValue: _settings['rewarded2'] ?? '',
            ),
            _buildTextField(
              'إعلان Rewarded 3',
              'rewarded3',
              initialValue: _settings['rewarded3'] ?? '',
            ),
            _buildTextField(
              'إعلان Rewarded 4',
              'rewarded4',
              initialValue: _settings['rewarded4'] ?? '',
            ),
            _buildTextField(
              'إعلان Rewarded 5',
              'rewarded5',
              initialValue: _settings['rewarded5'] ?? '',
            ),
            _buildTextField(
              'إعلان Rewarded 6',
              'rewarded6',
              initialValue: _settings['rewarded6'] ?? '',
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

  Widget _buildTextField(String label, String field, {String? initialValue}) {
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
        onSaved: (value) => _settings[field] = value,
      ),
    );
  }
}
