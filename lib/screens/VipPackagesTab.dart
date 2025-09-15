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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2D2D44),
        title: Text(
          'تأكيد الحذف',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذه الحزمة؟',
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
                  Uri.parse(
                    'https://dramaxbox.bbs.tr/App/api.php?action=manage_vip_packages',
                  ),
                  body: jsonEncode({'action': 'delete', 'id': id}),
                  headers: {'Content-Type': 'application/json'},
                );

                final data = jsonDecode(response.body);
                if (data['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حذف الحزمة بنجاح'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    )
                  );
                  _loadPackages();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل في حذف الحزمة'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    )
                  );
                }
              } catch (e) {
                print('Error deleting package: $e');
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
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          dialogBackgroundColor: Color(0xFF2D2D44),
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
          ),
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
                    isEdit ? 'تعديل حزمة VIP' : 'إضافة حزمة VIP جديدة',
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
                            labelText: 'اسم الحزمة',
                            prefixIcon: Icon(Icons.star, color: Colors.white70),
                          ),
                          onSaved: (value) => formData['name'] = value,
                          validator: (value) =>
                              value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: formData['duration'].toString(),
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'المدة (أيام)',
                            prefixIcon: Icon(Icons.calendar_today, color: Colors.white70),
                          ),
                          keyboardType: TextInputType.number,
                          onSaved: (value) => formData['duration'] = int.parse(value!),
                          validator: (value) =>
                              value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: formData['price'].toString(),
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'السعر',
                            prefixIcon: Icon(Icons.attach_money, color: Colors.white70),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onSaved: (value) => formData['price'] = double.parse(value!),
                          validator: (value) =>
                              value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: formData['google_play_product_id'],
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'معرف المنتج في Google Play',
                            prefixIcon: Icon(Icons.shop, color: Colors.white70),
                          ),
                          onSaved: (value) =>
                              formData['google_play_product_id'] = value,
                          validator: (value) =>
                              value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: formData['description'],
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'الوصف',
                            prefixIcon: Icon(Icons.description, color: Colors.white70),
                          ),
                          maxLines: 3,
                          onSaved: (value) => formData['description'] = value,
                        ),
                        SizedBox(height: 16),
                        CheckboxListTile(
                          title: Text(
                            'الحزمة مفعلة',
                            style: TextStyle(color: Colors.white70),
                          ),
                          activeColor: Color(0xFF6C63FF),
                          checkColor: Colors.white,
                          value: formData['is_active'] == 1,
                          onChanged: (value) => formData['is_active'] = value! ? 1 : 0,
                        ),
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
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                Navigator.pop(context);
                                _loadPackages();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('فشل في العملية'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  )
                                );
                              }
                            } catch (e) {
                              print('Error saving package: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء الحفظ'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                )
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(isEdit ? 'تعديل' : 'إضافة'),
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

  Widget _buildPackageCard(Map<String, dynamic> package) {
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
            color: Colors.amber.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.star,
            color: Colors.amber,
            size: 28,
          ),
        ),
        title: Text(
          package['name'],
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
              'المدة: ${package['duration']} يوم',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              'السعر: \$${package['price']}',
              style: TextStyle(color: Colors.white70),
            ),
            if (package['description'] != null && package['description'].isNotEmpty)
              Text(
                'الوصف: ${package['description']}',
                style: TextStyle(color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: package['is_active'] == 1 
                  ? Colors.green.withOpacity(0.2) 
                  : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                package['is_active'] == 1 ? 'مفعلة' : 'غير مفعلة',
                style: TextStyle(
                  color: package['is_active'] == 1 ? Colors.green : Colors.red,
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
              onPressed: () => _showEditPackageDialog(package: package),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deletePackage(package['id']),
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
              'جاري تحميل حزم VIP...',
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'حزم VIP',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditPackageDialog(),
                  icon: Icon(Icons.add, size: 20),
                  label: Text('إضافة حزمة جديدة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6C63FF),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _packages.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد حزم VIP',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _packages.length,
                    itemBuilder: (context, index) => _buildPackageCard(_packages[index]),
                  ),
          ),
        ],
      ),
    );
  }
}