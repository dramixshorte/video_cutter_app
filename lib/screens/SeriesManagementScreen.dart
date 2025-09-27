import 'package:flutter/material.dart';
import 'package:video_cutter_app/widgets/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'SeriesEditScreen.dart';
import 'SeriesEpisodesScreen.dart';

class SeriesManagementScreen extends StatefulWidget {
  const SeriesManagementScreen({super.key});

  @override
  State<SeriesManagementScreen> createState() => _SeriesManagementScreenState();
}

class _SeriesManagementScreenState extends State<SeriesManagementScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _series = [];
  List<Map<String, dynamic>> _filteredSeries = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce; // NEW: debounce timer

  // Arabic normalization
  String _normalize(String input) {
    var s = input;
    s = s.replaceAll(RegExp('[\u064B-\u0652]'), ''); // remove harakat
    s = s.replaceAll('ـ', ''); // tatweel
    s = s.replaceAll(RegExp('[إأآا]'), 'ا');
    s = s.replaceAll('ى', 'ي');
    s = s.replaceAll('ؤ', 'و');
    s = s.replaceAll('ئ', 'ي');
    s = s.replaceAll('ة', 'ه');
    return s.toLowerCase().trim();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _searchController.addListener(_onSearchChanged); // listen changes
    _loadSeries();
  }

  void _onSearchChanged() {
    final text = _searchController.text;
    if (text == _searchQuery) return;
    _searchQuery = text;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _filterSeries(_searchQuery),
    );
    setState(() {}); // update clear button
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSeries() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=get_series'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final mapped = data['series'].map<Map<String, dynamic>>((series) {
            return {
              'id': series['id'],
              'name': series['name'],
              'image_path': series['image_path'],
              'poster_url':
                  'https://dramaxbox.bbs.tr/App/series_images/${series['image_path']}',
              'episodes_count': series['episodes_count'] ?? 0,
              'status': 'active',
              'description': '${series['name']} - مسلسل متاح للمشاهدة',
            };
          }).toList();
          setState(() {
            _series = mapped;
            if (_searchQuery.trim().isEmpty) {
              _filteredSeries = _series;
            } else {
              _filterSeries(_searchQuery, internalCall: true);
            }
            _isLoading = false;
          });
          _animationController.forward();
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('خطأ في تحميل المسلسلات: $e', isError: true);
    }
  }

  void _filterSeries(String query, {bool internalCall = false}) {
    final raw = query;
    final q = _normalize(raw);
    setState(() {
      if (q.isEmpty) {
        _filteredSeries = _series;
      } else {
        _filteredSeries = _series.where((series) {
          final name = _normalize(series['name']?.toString() ?? '');
          final description = _normalize(
            series['description']?.toString() ?? '',
          );
          return name.contains(q) || description.contains(q);
        }).toList();
      }
      if (!internalCall) _searchQuery = raw; // keep original text
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    AppToast.show(
      context,
      message,
      type: isError ? ToastType.error : ToastType.success,
    );
  }

  Future<void> _sendSeriesNotification(Map<String, dynamic> series) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D44),
            title: const Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'إرسال إشعار',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'إرسال إشعار لجميع المستخدمين عن مسلسل "${series['name'] ?? 'غير محدد'}"؟\n\nالمستخدمون سيتمكنون من فتح المسلسل مباشرة من الإشعار.',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
                child: const Text('إرسال'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final response = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=send_notification',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'series',
          'series_id': series['id'],
          'title': series['name'],
          'body': 'مسلسل جديد متاح الآن للمشاهدة!',
          'image': series['poster_url'],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          _showMessage('تم إرسال الإشعار بنجاح! 🎉');
        } else {
          _showMessage(
            'فشل في إرسال الإشعار: ${result['message']}',
            isError: true,
          );
        }
      } else {
        _showMessage('خطأ في الخادم: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('فشل في إرسال الإشعار: $e', isError: true);
    }
  }

  Future<void> _deleteSeries(Map<String, dynamic> series) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D44),
            title: const Row(
              children: [
                Icon(Icons.delete, color: Color(0xFFE53E3E), size: 24),
                SizedBox(width: 12),
                Text(
                  'حذف المسلسل',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'هل أنت متأكد من حذف مسلسل "${series['name']}"؟\n\nسيتم حذف جميع الحلقات والصور المرتبطة به.',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53E3E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=delete_series'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'series_id': series['id'],
          'image_path': series['image_path'] ?? series['poster_url'] ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          _showMessage('تم حذف المسلسل بنجاح');
          _loadSeries(); // إعادة تحميل القائمة
        } else {
          _showMessage(
            'فشل في حذف المسلسل: ${result['message']}',
            isError: true,
          );
        }
      } else {
        _showMessage('خطأ في الخادم: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('فشل في حذف المسلسل: $e', isError: true);
    }
  }

  void _navigateToSeriesDetails(Map<String, dynamic> series) async {
    // فتح صفحة الحلقات بدلاً من التعديل
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeriesEpisodesScreen(series: series),
      ),
    );
  }

  void _navigateToEditSeries(Map<String, dynamic> series) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SeriesEditScreen(series: series)),
    );

    // إذا تم التعديل بنجاح، أعد تحميل القائمة
    if (result == true) {
      _loadSeries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'إدارة المسلسلات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4845D2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
              onPressed: _loadSeries,
            ),
          ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStatsRow(),
              _buildSearchBar(),
              Expanded(child: _buildSeriesList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4845D2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.video_library,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مكتبة المسلسلات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'إدارة المحتوى والإشعارات',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalSeries = _series.length;
    final activeSeries = _series.where((s) => s['status'] == 'active').length;
    final filteredCount = _filteredSeries.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF4845D2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('المجموع', totalSeries, Icons.list_alt),
          _buildStatItem('النشط', activeSeries, Icons.check_circle),
          _buildStatItem('الظاهر', filteredCount, Icons.visibility),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: _searchController,
        // removed onChanged direct call, handled by listener with debounce
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'البحث في المسلسلات...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(Icons.search, color: Color(0xFF6C63FF), size: 20),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    _filterSeries('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
        ),
      );
    }

    if (_filteredSeries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.movie_outlined,
                size: 64,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'لا توجد نتائج بحث' : 'لا توجد مسلسلات',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'جرب البحث بكلمات مختلفة',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredSeries.length,
      itemBuilder: (context, index) {
        final series = _filteredSeries[index];
        return _buildSeriesCard(series, index);
      },
    );
  }

  Widget _buildSeriesCard(Map<String, dynamic> series, int index) {
    final isActive = series['status'] == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToSeriesDetails(series),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF4CAF50).withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الصورة
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 70,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D44),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          series['poster_url'] != null &&
                              series['poster_url'].toString().isNotEmpty
                          ? Image.network(
                              series['poster_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholderImage(),
                            )
                          : _buildPlaceholderImage(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // المحتوى
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                series['name'] ?? 'بدون اسم',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // الجرس الأخضر للإشعارات 🔔
                            GestureDetector(
                              onTap: () => _sendSeriesNotification(series),
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF4CAF50),
                                      Color(0xFF45A049),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF4CAF50,
                                      ).withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.notifications_active,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // زر التعديل
                            GestureDetector(
                              onTap: () => _navigateToEditSeries(series),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6C63FF,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF6C63FF),
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // زر الحذف
                            GestureDetector(
                              onTap: () => _deleteSeries(series),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE53E3E,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Color(0xFFE53E3E),
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (series['description'] != null &&
                            series['description'].toString().isNotEmpty)
                          Text(
                            series['description'].toString(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isActive
                                      ? [
                                          const Color(0xFF4CAF50),
                                          const Color(0xFF45A049),
                                        ]
                                      : [
                                          const Color(0xFF757575),
                                          const Color(0xFF616161),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'نشط' : 'غير نشط',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${series['episodes_count'] ?? 0} حلقة',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFF2D2D44),
      child: const Icon(Icons.movie, color: Colors.white54, size: 30),
    );
  }
}
