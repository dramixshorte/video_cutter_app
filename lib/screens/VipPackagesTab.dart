import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_cutter_app/widgets/app_toast.dart';

class VipPackagesTab extends StatefulWidget {
  const VipPackagesTab({super.key});

  @override
  _VipPackagesTabState createState() => _VipPackagesTabState();
}

class _VipPackagesTabState extends State<VipPackagesTab>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<dynamic> _packages = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _loadPackages();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);
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
        _animationController.forward();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading packages: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('خطأ في تحميل حزم VIP');
    }
  }

  void _showSuccessSnackBar(String message) =>
      AppToast.show(context, message, type: ToastType.success);
  void _showErrorSnackBar(String message) =>
      AppToast.show(context, message, type: ToastType.error);

  List<dynamic> get _filteredPackages {
    if (_searchQuery.isEmpty) return _packages;
    return _packages.where((package) {
      final name = package['name'].toString().toLowerCase();
      final price = package['price'].toString().toLowerCase();
      final duration = package['duration'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          price.contains(query) ||
          duration.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E2E),
      body: SafeArea(
        child: _isLoading ? _buildLoadingWidget() : _buildMainContent(),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF3D3D5A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'جاري تحميل حزم VIP...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF3D3D5A)],
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildPackagesList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: EdgeInsets.all(12),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة حزم VIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'تحكم في حزم العضوية المميزة',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'البحث في حزم VIP...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.6),
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showPackageDialog(),
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesList() {
    final filteredPackages = _filteredPackages;

    if (filteredPackages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_outline,
                color: Colors.white.withOpacity(0.6),
                size: 64,
              ),
            ),
            SizedBox(height: 20),
            Text(
              _searchQuery.isEmpty ? 'لا توجد حزم VIP' : 'لا توجد نتائج للبحث',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'ابدأ بإضافة حزمة VIP جديدة'
                  : 'جرب مصطلحات بحث مختلفة',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filteredPackages.length,
      itemBuilder: (context, index) {
        final package = filteredPackages[index];
        return _buildPackageCard(package, index);
      },
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package, int index) {
    final isActive = package['is_active'] == 1;
    final packageName = package['name'] ?? 'VIP Package';
    final price = package['price'] ?? 0;
    final duration = package['duration'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPackageDialog(package: package),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isActive
                    ? [
                        Color(0xFFFFD700).withOpacity(0.1),
                        Color(0xFFFFA500).withOpacity(0.1),
                      ]
                    : [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? Color(0xFFFFD700).withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActive
                          ? [Color(0xFFFFD700), Color(0xFFFFA500)]
                          : [Color(0x000ff666), Color(0x000ff555)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.star,
                    color: isActive ? Colors.black : Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              packageName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Color(0xFF4CAF50).withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'مفعلة' : 'معطلة',
                              style: TextStyle(
                                color: isActive
                                    ? Color(0xFF4CAF50)
                                    : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'السعر: \$$price - المدة: $duration يوم',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (package['description'] != null &&
                          package['description'].toString().isNotEmpty)
                        Text(
                          package['description'],
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white70),
                  color: Color(0xFF2D2D44),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showPackageDialog(package: package);
                    } else if (value == 'delete') {
                      _deletePackage(package);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPackageDialog({Map<String, dynamic>? package}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPackageFormDialog(package: package),
    );
  }

  Widget _buildPackageFormDialog({Map<String, dynamic>? package}) {
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

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: 560),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D2D44), Color(0xFF1E1E2E), Color(0xFF2D2D44)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit : Icons.star,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit
                                  ? 'تعديل حزمة VIP'
                                  : 'إضافة حزمة VIP جديدة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (isEdit)
                              Text(
                                'تعديل بيانات الحزمة',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Compact Form Fields
                _buildCompactFormField(
                  label: 'اسم حزمة VIP',
                  icon: Icons.star,
                  initialValue: formData['name'] ?? '',
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  onSaved: (value) => formData['name'] = value,
                  hint: 'VIP الذهبية',
                ),
                SizedBox(height: 12),

                _buildCompactFormField(
                  label: 'المدة (أيام)',
                  icon: Icons.calendar_today,
                  initialValue: formData['duration'].toString(),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  onSaved: (value) => formData['duration'] = int.parse(value!),
                  hint: '30',
                ),
                SizedBox(height: 12),

                _buildCompactFormField(
                  label: 'السعر (\$)',
                  icon: Icons.attach_money,
                  initialValue: formData['price'].toString(),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  onSaved: (value) => formData['price'] = double.parse(value!),
                  hint: '9.99',
                ),
                SizedBox(height: 12),

                _buildCompactFormField(
                  label: 'معرف Google Play',
                  icon: Icons.shop,
                  initialValue: formData['google_play_product_id'] ?? '',
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  onSaved: (value) =>
                      formData['google_play_product_id'] = value,
                  hint: 'com.example.vip',
                ),
                SizedBox(height: 12),

                _buildCompactFormField(
                  label: 'الوصف (اختياري)',
                  icon: Icons.description,
                  initialValue: formData['description'] ?? '',
                  onSaved: (value) => formData['description'] = value,
                  hint: 'وصف الحزمة...',
                  maxLines: 2,
                ),
                SizedBox(height: 16),

                // Compact Active Toggle
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: StatefulBuilder(
                    builder: (context, setDialogState) => Row(
                      children: [
                        Icon(
                          Icons.toggle_on,
                          color: Color(0xFFFFD700),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'حزمة مفعلة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch(
                          value: formData['is_active'] == 1,
                          onChanged: (value) {
                            setDialogState(() {
                              formData['is_active'] = value ? 1 : 0;
                            });
                          },
                          activeThumbColor: Color(0xFFFFD700),
                          activeTrackColor: Color(0xFFFFD700).withOpacity(0.3),
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Compact Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                        child: Text(
                          'إلغاء',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _submitPackageForm(
                          formKey,
                          formData,
                          isEdit,
                          package,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isEdit ? Icons.save : Icons.add, size: 16),
                            SizedBox(width: 6),
                            Text(
                              isEdit ? 'حفظ' : 'إضافة',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFormField({
    required String label,
    required IconData icon,
    required String initialValue,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
    String? hint,
    int? maxLines,
  }) {
    return TextFormField(
      initialValue:
          initialValue == '' || initialValue == '0' || initialValue == '0.0'
          ? ''
          : initialValue,
      keyboardType: keyboardType,
      validator: validator,
      onSaved: onSaved,
      maxLines: maxLines ?? 1,
      style: TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(color: Colors.white70, fontSize: 13),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 13,
        ),
      ),
    );
  }

  void _submitPackageForm(
    GlobalKey<FormState> formKey,
    Map<String, dynamic> formData,
    bool isEdit,
    Map<String, dynamic>? originalPackage,
  ) async {
    if (!formKey.currentState!.validate()) return;
    formKey.currentState!.save();

    try {
      Navigator.pop(context);

      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_vip_packages',
        ),
        body: jsonEncode({
          'action': isEdit ? 'update' : 'create',
          if (isEdit) 'id': originalPackage!['id'],
          ...formData,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showSuccessSnackBar(
          isEdit ? 'تم تحديث حزمة VIP بنجاح' : 'تم إضافة حزمة VIP بنجاح',
        );
        await _loadPackages();
      } else {
        _showErrorSnackBar(data['message'] ?? 'حدث خطأ أثناء العملية');
      }
    } catch (e) {
      print('Error submitting form: $e');
      _showErrorSnackBar('خطأ في الاتصال بالخادم');
    }
  }

  void _deletePackage(Map<String, dynamic> package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تأكيد الحذف',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت متأكد من حذف حزمة VIP "${package['name']}"؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => _confirmDeletePackage(package),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePackage(Map<String, dynamic> package) async {
    Navigator.pop(context);
    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_vip_packages',
        ),
        body: jsonEncode({'action': 'delete', 'id': package['id']}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showSuccessSnackBar('تم حذف حزمة VIP بنجاح');
        await _loadPackages();
      } else {
        _showErrorSnackBar(data['message'] ?? 'حدث خطأ أثناء الحذف');
      }
    } catch (e) {
      print('Error deleting package: $e');
      _showErrorSnackBar('خطأ في الاتصال بالخادم');
    }
  }
}
