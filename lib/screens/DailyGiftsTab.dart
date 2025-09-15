
// الهدايا اليومية
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DailyGiftsTab extends StatefulWidget {
  @override
  _DailyGiftsTabState createState() => _DailyGiftsTabState();
}

class _DailyGiftsTabState extends State<DailyGiftsTab> {
  List<dynamic> _gifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_daily_gifts',
        ),
        body: jsonEncode({'action': 'get_all'}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _gifts = data['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading gifts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteGift(int id) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_daily_gifts',
        ),
        body: jsonEncode({'action': 'delete', 'id': id}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم حذف الهدية بنجاح')));
        _loadGifts();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في حذف الهدية')));
      }
    } catch (e) {
      print('Error deleting gift: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف')));
    }
  }

  void _showEditGiftDialog({Map<String, dynamic>? gift}) {
    final isEdit = gift != null;
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> formData = isEdit
        ? Map.from(gift)
        : {
            'coin_amount': '',
            'price': '',
            'required_ads': '',
            'cooldown_hours': '',
            'is_popular': 0,
          };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'تعديل الهدية' : 'إضافة هدية جديدة'),
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
                  initialValue: formData['cooldown_hours'].toString(),
                  decoration: InputDecoration(
                    labelText: 'مدة الانتظار (ساعات)',
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: (value) =>
                      formData['cooldown_hours'] = int.parse(value!),
                  validator: (value) =>
                      value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                CheckboxListTile(
                  title: Text('عرض كهدية شعبية'),
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
                      'https://dramaxbox.bbs.tr/App/api.php?action=manage_daily_gifts',
                    ),
                    body: jsonEncode({
                      'action': isEdit ? 'update' : 'create',
                      ...formData,
                      if (isEdit) 'id': gift['id'],
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
                    _loadGifts();
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('فشل في العملية')));
                  }
                } catch (e) {
                  print('Error saving gift: $e');
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
                'الهدايا اليومية',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showEditGiftDialog(),
                icon: Icon(Icons.add),
                label: Text('إضافة هدية جديدة'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _gifts.length,
            itemBuilder: (context, index) {
              final gift = _gifts[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.card_giftcard, color: Colors.pink),
                  title: Text('${gift['coin_amount']} عملة'),
                  subtitle: Text(
                    'السعر: ${gift['price']} - مدة الانتظار: ${gift['cooldown_hours']} ساعة',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditGiftDialog(gift: gift),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteGift(gift['id']),
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
