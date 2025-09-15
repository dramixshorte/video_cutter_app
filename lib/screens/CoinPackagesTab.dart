
// حزم العملات
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CoinPackagesTab extends StatefulWidget {
  @override
  _CoinPackagesTabState createState() => _CoinPackagesTabState();
}

class _CoinPackagesTabState extends State<CoinPackagesTab> {
  List<dynamic> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_coin_packages',
        ),
        body: jsonEncode({'action': 'get_all'}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _packages = data['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading packages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePackage(int id) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_coin_packages',
        ),
        body: jsonEncode({'action': 'delete', 'id': id}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم حذف الحزمة بنجاح')));
        _loadPackages();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في حذف الحزمة')));
      }
    } catch (e) {
      print('Error deleting package: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف')));
    }
  }

  void _showEditPackageDialog({Map<String, dynamic>? package}) {
    final isEdit = package != null;
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> formData = isEdit
        ? Map.from(package)
        : {
            'coin_amount': '',
            'price': '',
            'required_ads': '',
            'google_play_product_id': '',
            'is_popular': 0,
          };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'تعديل الحزمة' : 'إضافة حزمة جديدة'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: formData['coin_amount'].toString(),
                  decoration: InputDecoration(labelText: 'عدد العملات'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) =>
                      formData['coin_amount'] = int.parse(value!),
                  validator: (value) =>
                      value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                TextFormField(
                  initialValue: formData['price'].toString(),
                  decoration: InputDecoration(labelText: 'السعر'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => formData['price'] = double.parse(value!),
                  validator: (value) =>
                      value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                TextFormField(
                  initialValue: formData['required_ads'].toString(),
                  decoration: InputDecoration(
                    labelText: 'عدد الإعلانات المطلوبة',
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: (value) =>
                      formData['required_ads'] = int.parse(value!),
                  validator: (value) =>
                      value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                TextFormField(
                  initialValue: formData['google_play_product_id'],
                  decoration: InputDecoration(
                    labelText: 'معرف المنتج في Google Play',
                  ),
                  onSaved: (value) =>
                      formData['google_play_product_id'] = value,
                  validator: (value) =>
                      value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                CheckboxListTile(
                  title: Text('عرض كحزمة شعبية'),
                  value: formData['is_popular'] == 1,
                  onChanged: (value) => formData['is_popular'] = value! ? 1 : 0,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();

                try {
                  final response = await http.post(
                    Uri.parse(
                      'https://dramaxbox.bbs.tr/App/api.php?action=manage_coin_packages',
                    ),
                    body: jsonEncode({
                      'action': isEdit ? 'update' : 'create',
                      ...formData,
                      if (isEdit) 'id': package['id'],
                    }),
                    headers: {'Content-Type': 'application/json'},
                  );

                  final data = jsonDecode(response.body);
                  if (data['status'] == 'success') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit ? 'تم التعديل بنجاح' : 'تم الإضافة بنجاح',
                        ),
                      ),
                    );
                    Navigator.pop(context);
                    _loadPackages();
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('فشل في العملية')));
                  }
                } catch (e) {
                  print('Error saving package: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ أثناء الحفظ')),
                  );
                }
              }
            },
            child: Text(isEdit ? 'تعديل' : 'إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'حزم العملات',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showEditPackageDialog(),
                icon: Icon(Icons.add),
                label: Text('إضافة حزمة جديدة'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _packages.length,
            itemBuilder: (context, index) {
              final package = _packages[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.monetization_on, color: Colors.amber),
                  title: Text('${package['coin_amount']} عملة'),
                  subtitle: Text(
                    'السعر: ${package['price']} - الإعلانات المطلوبة: ${package['required_ads']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _showEditPackageDialog(package: package),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePackage(package['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
