
// حزم VIP
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VipPackagesTab extends StatefulWidget {
  @override
  _VipPackagesTabState createState() => _VipPackagesTabState();
}

class _VipPackagesTabState extends State<VipPackagesTab> {
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
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_vip_packages',
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
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_vip_packages',
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
            'name': '',
            'duration': '',
            'price': '',
            'google_play_product_id': '',
            'description': '',
            'is_active': 1,
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
                  initialValue: formData['name'],
                  decoration: InputDecoration(labelText: 'اسم الحزمة'),
                  onSaved: (value) => formData['name'] = value,
                  validator: (value) =>
                      value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                TextFormField(
                  initialValue: formData['duration'].toString(),
                  decoration: InputDecoration(labelText: 'المدة (أيام)'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => formData['duration'] = int.parse(value!),
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
                  initialValue: formData['google_play_product_id'],
                  decoration: InputDecoration(
                    labelText: 'معرف المنتج في Google Play',
                  ),
                  onSaved: (value) =>
                      formData['google_play_product_id'] = value,
                  validator: (value) =>
                      value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                TextFormField(
                  initialValue: formData['description'],
                  decoration: InputDecoration(labelText: 'الوصف'),
                  onSaved: (value) => formData['description'] = value,
                ),
                CheckboxListTile(
                  title: Text('الحزمة مفعلة'),
                  value: formData['is_active'] == 1,
                  onChanged: (value) => formData['is_active'] = value! ? 1 : 0,
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
                      'https://dramaxbox.bbs.tr/App/api.php?action=manage_vip_packages',
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
                'حزم VIP',
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
                  leading: Icon(Icons.star, color: Colors.amber),
                  title: Text(package['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المدة: ${package['duration']} يوم'),
                      Text('السعر: ${package['price']}'),
                      Text(
                        'الحالة: ${package['is_active'] == 1 ? 'مفعلة' : 'غير مفعلة'}',
                      ),
                    ],
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
