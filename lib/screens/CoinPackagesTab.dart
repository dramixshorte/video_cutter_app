import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CoinPackagesTab extends StatefulWidget {
  const CoinPackagesTab({super.key});

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
                    isEdit ? 'تعديل الحزمة' : 'إضافة حزمة جديدة',
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
                          initialValue: formData['coin_amount'].toString(),
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'عدد العملات',
                            prefixIcon: Icon(Icons.monetization_on, color: Colors.white70),
                          ),
                          keyboardType: TextInputType.number,
                          onSaved: (value) =>
                              formData['coin_amount'] = int.parse(value!),
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
                          initialValue: formData['required_ads'].toString(),
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'عدد الإعلانات المطلوبة',
                            prefixIcon: Icon(Icons.ad_units, color: Colors.white70),
                          ),
                          keyboardType: TextInputType.number,
                          onSaved: (value) =>
                              formData['required_ads'] = int.parse(value!),
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
                        CheckboxListTile(
                          title: Text(
                            'عرض كحزمة شعبية',
                            style: TextStyle(color: Colors.white70),
                          ),
                          activeColor: Color(0xFF6C63FF),
                          checkColor: Colors.white,
                          value: formData['is_popular'] == 1,
                          onChanged: (value) => formData['is_popular'] = value! ? 1 : 0,
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
              'جاري تحميل حزم العملات...',
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
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'حزم العملات',
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
                      'لا توجد حزم عملات',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _packages.length,
                    itemBuilder: (context, index) {
                      final package = _packages[index];
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Color(0xFF6C63FF).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.monetization_on,
                              color: Colors.amber,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            '${package['coin_amount']} عملة',
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
                                'السعر: \$${package['price']}',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'الإعلانات المطلوبة: ${package['required_ads']}',
                                style: TextStyle(color: Colors.white70),
                              ),
                              if (package['is_popular'] == 1)
                                Container(
                                  margin: EdgeInsets.only(top: 4),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'شعبية',
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
      ),
    );
  }
}