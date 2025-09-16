import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UsersManagementTab extends StatefulWidget {
  const UsersManagementTab({super.key});

  @override
  _UsersManagementTabState createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<UsersManagementTab> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers({int page = 1, String? search}) async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_users'),
        body: jsonEncode({
          'action': 'get_all', 
          'page': page, 
          'limit': 20,
          'search': search
        }),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث بيانات المستخدم بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
        _loadUsers(page: _currentPage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحديث البيانات'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      print('Error updating user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التحديث'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  Future<void> _deleteUser(int id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2D2D44),
        title: Text(
          'تأكيد الحذف',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذا المستخدم؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final response = await http.post(
                  Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=manage_users'),
                  body: jsonEncode({'action': 'delete', 'id': id}),
                  headers: {'Content-Type': 'application/json'},
                );

                final data = jsonDecode(response.body);
                if (data['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حذف المستخدم بنجاح'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    )
                  );
                  _loadUsers(page: _currentPage);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل في حذف المستخدم'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    )
                  );
                }
              } catch (e) {
                print('Error deleting user: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ أثناء الحذف'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  )
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> formData = Map.from(user);

    showDialog(
      context: context,
      builder: (context) => Theme(
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
            labelStyle: TextStyle(color: Colors.white70),
          ), dialogTheme: DialogThemeData(backgroundColor: Color(0xFF2D2D44)),
        ),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF2D2D44),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعديل بيانات المستخدم',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          initialValue: formData['name'],
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'الاسم',
                            prefixIcon: Icon(Icons.person, color: Colors.white70),
                          ),
                          onSaved: (value) => formData['name'] = value,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: formData['email'],
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email, color: Colors.white70),
                          ),
                          onSaved: (value) => formData['email'] = value,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: formData['coins'].toString(),
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'عدد العملات',
                            prefixIcon: Icon(Icons.monetization_on, color: Colors.white70),
                          ),
                          keyboardType: TextInputType.number,
                          onSaved: (value) => formData['coins'] = int.parse(value!),
                        ),
                        SizedBox(height: 16),
                        CheckboxListTile(
                          title: Text(
                            'عضوية VIP',
                            style: TextStyle(color: Colors.white70),
                          ),
                          activeColor: Color(0xFF6C63FF),
                          checkColor: Colors.white,
                          value: formData['is_vip'] == 1,
                          onChanged: (value) => formData['is_vip'] = value! ? 1 : 0,
                        ),
                        if (formData['is_vip'] == 1) ...[
                          SizedBox(height: 16),
                          TextFormField(
                            initialValue: formData['vip_expiry'],
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'انتهاء الـ VIP (YYYY-MM-DD)',
                              prefixIcon: Icon(Icons.calendar_today, color: Colors.white70),
                            ),
                            onSaved: (value) => formData['vip_expiry'] = value,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'إلغاء',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            formKey.currentState!.save();
                            _updateUser(user['id'], formData);
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('حفظ التعديلات'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            color: Colors.blue,
            size: 28,
          ),
        ),
        title: Text(
          user['name'] ?? 'بدون اسم',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'البريد: ${user['email'] ?? 'غير محدد'}',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              'العملات: ${user['coins']}',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              'المعاملات: ${user['transactions_count']}',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              'المشتريات: ${user['purchases_count']}',
              style: TextStyle(color: Colors.white70),
            ),
            if (user['is_vip'] == 1)
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'VIP حتى: ${user['vip_expiry'] ?? 'غير محدد'}',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              'جاري تحميل المستخدمين...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'إدارة المستخدمين',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث عن مستخدم...',
                  hintStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (value) => _loadUsers(page: 1, search: value),
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _users.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد مستخدمين',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _users.length,
                    itemBuilder: (context, index) => _buildUserCard(_users[index]),
                  ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, size: 20),
                  color: _currentPage > 1 ? Colors.white : Colors.white30,
                  onPressed: _currentPage > 1
                      ? () => _loadUsers(page: _currentPage - 1)
                      : null,
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'الصفحة $_currentPage من $_totalPages',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 20),
                  color: _currentPage < _totalPages ? Colors.white : Colors.white30,
                  onPressed: _currentPage < _totalPages
                      ? () => _loadUsers(page: _currentPage + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}