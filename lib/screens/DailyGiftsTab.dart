import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_cutter_app/widgets/app_toast.dart';

class DailyGiftsTab extends StatefulWidget {
  const DailyGiftsTab({super.key});

  @override
  _DailyGiftsTabState createState() => _DailyGiftsTabState();
}

class _DailyGiftsTabState extends State<DailyGiftsTab>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<dynamic> _gifts = [];
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
    _loadGifts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGifts() async {
    setState(() => _isLoading = true);
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
        _animationController.forward();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading gifts: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('خطأ في تحميل الهدايا اليومية');
    }
  }

  void _showSuccessSnackBar(String message) =>
      AppToast.show(context, message, type: ToastType.success);
  void _showErrorSnackBar(String message) =>
      AppToast.show(context, message, type: ToastType.error);

  List<dynamic> get _filteredGifts {
    if (_searchQuery.isEmpty) return _gifts;
    return _gifts
        .where(
          (gift) =>
              gift['day_number'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              gift['coins_reward'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (gift['description'] ?? '').toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'جاري تحميل الهدايا اليومية...',
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
              Expanded(child: _buildGiftsList()),
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
                      'إدارة الهدايا اليومية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'تحكم في هدايا المستخدمين اليومية',
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
                      hintText: 'البحث في الهدايا اليومية...',
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
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showGiftDialog(),
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

  Widget _buildGiftsList() {
    final filteredGifts = _filteredGifts;

    if (filteredGifts.isEmpty) {
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
                Icons.card_giftcard_outlined,
                color: Colors.white.withOpacity(0.6),
                size: 64,
              ),
            ),
            SizedBox(height: 20),
            Text(
              _searchQuery.isEmpty
                  ? 'لا توجد هدايا يومية'
                  : 'لا توجد نتائج للبحث',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'ابدأ بإضافة هدية يومية جديدة'
                  : 'جرب مصطلحات بحث مختلفة',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filteredGifts.length,
      itemBuilder: (context, index) {
        final gift = filteredGifts[index];
        return _buildGiftCard(gift, index);
      },
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> gift, int index) {
    final dayNumber = gift['day_number'] ?? 0;
    final coins = gift['coins_reward'] ?? 0;
    final isSpecial = dayNumber % 7 == 0; // Special every 7 days

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGiftDialog(gift: gift),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSpecial
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
                color: isSpecial
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
                      colors: isSpecial
                          ? [Color(0xFFFFD700), Color(0xFFFFA500)]
                          : [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSpecial ? Icons.stars : Icons.card_giftcard,
                    color: Colors.white,
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
                          Text(
                            'اليوم $dayNumber',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isSpecial) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'مميز',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'المكافأة: $coins عملة',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (gift['description'] != null &&
                          gift['description'].toString().isNotEmpty)
                        Text(
                          gift['description'],
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
                      _showGiftDialog(gift: gift);
                    } else if (value == 'delete') {
                      _confirmDeleteGift(gift);
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

  void _showGiftDialog({Map<String, dynamic>? gift}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildGiftFormDialog(gift: gift),
    );
  }

  Widget _buildGiftFormDialog({Map<String, dynamic>? gift}) {
    final isEdit = gift != null;
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> formData = isEdit
        ? Map.from(gift)
        : {'day_number': '', 'coins_reward': '', 'description': ''};

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
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
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
                          isEdit ? Icons.edit : Icons.card_giftcard,
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
                              isEdit ? 'تعديل الهدية' : 'إضافة هدية جديدة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (isEdit)
                              Text(
                                'تعديل بيانات الهدية',
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
                  label: 'رقم اليوم',
                  icon: Icons.calendar_today,
                  initialValue: formData['day_number'].toString(),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  onSaved: (value) =>
                      formData['day_number'] = int.parse(value!),
                  hint: '1',
                ),
                SizedBox(height: 12),

                _buildCompactFormField(
                  label: 'عدد العملات',
                  icon: Icons.monetization_on,
                  initialValue: formData['coins_reward'].toString(),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  onSaved: (value) =>
                      formData['coins_reward'] = int.parse(value!),
                  hint: '50',
                ),
                SizedBox(height: 12),

                _buildCompactFormField(
                  label: 'الوصف (اختياري)',
                  icon: Icons.description,
                  initialValue: formData['description'] ?? '',
                  onSaved: (value) => formData['description'] = value ?? '',
                  hint: 'وصف الهدية...',
                  maxLines: 2,
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
                        onPressed: () =>
                            _submitGiftForm(formKey, formData, isEdit, gift),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFF6B6B),
                          foregroundColor: Colors.white,
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
      initialValue: initialValue == '' || initialValue == '0'
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
          borderSide: BorderSide(color: Color(0xFFFF6B6B), width: 2),
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

  void _submitGiftForm(
    GlobalKey<FormState> formKey,
    Map<String, dynamic> formData,
    bool isEdit,
    Map<String, dynamic>? originalGift,
  ) async {
    if (!formKey.currentState!.validate()) return;
    formKey.currentState!.save();

    try {
      Navigator.pop(context);

      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_daily_gifts',
        ),
        body: jsonEncode({
          'action': isEdit ? 'update' : 'add',
          if (isEdit) 'id': originalGift!['id'],
          ...formData,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showSuccessSnackBar(
          isEdit ? 'تم تحديث الهدية بنجاح' : 'تم إضافة الهدية بنجاح',
        );
        await _loadGifts();
      } else {
        _showErrorSnackBar(data['message'] ?? 'حدث خطأ أثناء العملية');
      }
    } catch (e) {
      print('Error submitting form: $e');
      _showErrorSnackBar('خطأ في الاتصال بالخادم');
    }
  }

  void _confirmDeleteGift(Map<String, dynamic> gift) {
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
          'هل أنت متأكد من حذف هدية اليوم ${gift['day_number']}؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => _deleteGift(gift),
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

  void _deleteGift(Map<String, dynamic> gift) async {
    Navigator.pop(context);
    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=manage_daily_gifts',
        ),
        body: jsonEncode({'action': 'delete', 'id': gift['id']}),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showSuccessSnackBar('تم حذف الهدية بنجاح');
        await _loadGifts();
      } else {
        _showErrorSnackBar(data['message'] ?? 'حدث خطأ أثناء الحذف');
      }
    } catch (e) {
      print('Error deleting gift: $e');
      _showErrorSnackBar('خطأ في الاتصال بالخادم');
    }
  }
}
