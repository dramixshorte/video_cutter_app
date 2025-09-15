
// إدارة المستخدمين
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UsersManagementTab extends StatefulWidget {
  @override
  _UsersManagementTabState createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<UsersManagementTab> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers({int page = 1}) async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_users'),
        body: jsonEncode({'action': 'get_all', 'page': page, 'limit': 20}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _users = data['data'] ?? [];
          _currentPage = page;
          _totalPages = data['pagination']['total_pages'] ?? 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUser(int id, Map<String, dynamic> updates) async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_users'),
        body: jsonEncode({'action': 'update', 'id': id, ...updates}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم التعديل بنجاح')));
        _loadUsers(page: _currentPage);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في التعديل')));
      }
    } catch (e) {
      print('Error updating user: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التعديل')));
    }
  }

  Future<void> _deleteUser(int id) async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_users'),
        body: jsonEncode({'action': 'delete', 'id': id}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم حذف المستخدم بنجاح')));
        _loadUsers(page: _currentPage);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في حذف المستخدم')));
      }
    } catch (e) {
      print('Error deleting user: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف')));
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> formData = Map.from(user);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل المستخدم'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: formData['name'],
                  decoration: InputDecoration(labelText: 'الاسم'),
                  onSaved: (value) => formData['name'] = value,
                ),
                TextFormField(
                  initialValue: formData['email'],
                  decoration: InputDecoration(labelText: 'البريد الإلكتروني'),
                  onSaved: (value) => formData['email'] = value,
                ),
                TextFormField(
                  initialValue: formData['coins'].toString(),
                  decoration: InputDecoration(labelText: 'عدد العملات'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => formData['coins'] = int.parse(value!),
                ),
                CheckboxListTile(
                  title: Text('عضوية VIP'),
                  value: formData['is_vip'] == 1,
                  onChanged: (value) => formData['is_vip'] = value! ? 1 : 0,
                ),
                if (formData['is_vip'] == 1)
                  TextFormField(
                    initialValue: formData['vip_expiry'],
                    decoration: InputDecoration(
                      labelText: 'انتهاء الـ VIP (YYYY-MM-DD)',
                    ),
                    onSaved: (value) => formData['vip_expiry'] = value,
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                _updateUser(user['id'], formData);
                Navigator.pop(context);
              }
            },
            child: Text('تعديل'),
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
          child: Text(
            'إدارة المستخدمين',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.person, color: Colors.blue),
                        title: Text(user['name'] ?? 'بدون اسم'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('البريد: ${user['email'] ?? 'غير محدد'}'),
                            Text('العملات: ${user['coins']}'),
                            Text('المعاملات: ${user['transactions_count']}'),
                            Text('المشتريات: ${user['purchases_count']}'),
                            if (user['is_vip'] == 1)
                              Text(
                                'VIP حتى: ${user['vip_expiry'] ?? 'غير محدد'}',
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditUserDialog(user),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(user['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: _currentPage > 1
                          ? () => _loadUsers(page: _currentPage - 1)
                          : null,
                    ),
                    Text('الصفحة $_currentPage من $_totalPages'),
                    IconButton(
                      icon: Icon(Icons.arrow_forward),
                      onPressed: _currentPage < _totalPages
                          ? () => _loadUsers(page: _currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
