// CLEAN REWRITE: شاشة عرض المسلسلات مع نفس أزرار وإجراءات شاشة الإدارة

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_cutter_app/widgets/app_toast.dart';
// أزلنا الاعتماد على ProDialog في الحذف لأنه يسبب تجمّد أحياناً.
// نستخدم BottomSheet خفيف للتأكيد.
import 'package:video_cutter_app/widgets/pro_dialog.dart'; // ما زال مستخدم لإرسال الإشعار فقط حالياً
import 'package:http/http.dart' as http;
import 'SeriesEditScreen.dart';
import 'SeriesEpisodesScreen.dart';

class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key});
  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _series = [];
  final Map<int, bool> _actionLoading = {}; // حالة تحميل لكل مسلسل
  // SEARCH STATE
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];
  String _query = '';
  Timer? _debounce;

  // Arabic normalization helper
  String _normalize(String input) {
    var s = input;
    s = s.replaceAll(RegExp('[\u064B-\u0652]'), ''); // حركات
    s = s.replaceAll('ـ', ''); // تطويل
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
    _fetch();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text;
    if (newQuery == _query) return;
    _query = newQuery;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _applyFilter);
    setState(() {}); // لتحديث زر المسح
  }

  void _applyFilter() {
    if (_query.trim().isEmpty) {
      setState(() {
        _filtered = _series;
      });
      return;
    }
    final nq = _normalize(_query);
    final res = _series.where((s) {
      final name = _normalize((s['name'] ?? '').toString());
      final desc = _normalize((s['description'] ?? '').toString());
      return name.contains(nq) || desc.contains(nq);
    }).toList();
    setState(() {
      _filtered = res;
    });
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
        'https://dramaxbox.bbs.tr/App/api.php?action=get_all_series',
      );
      final client = HttpClient();
      final req = await client.getUrl(uri);
      final resp = await req.close();
      final txt = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final map = jsonDecode(txt);
      if (map['status'] != 'success') {
        throw Exception(map['message'] ?? 'فشل جلب البيانات');
      }
      final raw = (map['data'] as List?) ?? [];
      final mapped = raw.map<Map<String, dynamic>>((s) {
        final img = s['image_path'];
        return {
          'id': s['id'],
          'name': s['name'],
          'image_path': img,
          'poster_url': img == null
              ? null
              : 'https://dramaxbox.bbs.tr/App/series_images/$img',
          'episodes_count': s['episodes_count'] ?? 0,
          'description':
              s['description'] ?? '${s['name']} - مسلسل متاح للمشاهدة',
          'status': 'active',
        };
      }).toList();
      setState(() {
        _series = mapped;
        // إعادة بناء الفلترة مع الاستعلام الحالي إن وجد
        if (_query.trim().isEmpty) {
          _filtered = _series;
        } else {
          _applyFilter();
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    AppToast.show(
      context,
      msg,
      type: error ? ToastType.error : ToastType.success,
    );
  }

  Future<void> _sendSeriesNotification(Map<String, dynamic> series) async {
    final id = series['id'];
    if (_actionLoading[id] == true) return;
    final confirmed = await ProDialog.confirm(
      context,
      title: 'إرسال إشعار',
      message: 'إرسال إشعار للمستخدمين عن "${series['name']}"؟',
      confirmText: 'إرسال',
      icon: Icons.notifications_active,
      color: const Color(0xFF4CAF50),
    );
    if (!confirmed) return;
    setState(() => _actionLoading[id] = true);
    try {
      final resp = await http.post(
        Uri.parse(
          'https://dramaxbox.bbs.tr/App/api.php?action=send_notification',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'series',
          'series_id': id,
          'title': series['name'],
          'body': 'مشاهدة ممتعة لمسلسل جديد!',
          'image': series['poster_url'],
          'description': series['description'],
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['status'] == 'success') {
          _showSnack('تم إرسال الإشعار');
        } else {
          _showSnack('فشل: ${data['message']}', error: true);
        }
      } else {
        _showSnack('HTTP ${resp.statusCode}', error: true);
      }
    } catch (e) {
      _showSnack('خطأ: $e', error: true);
    } finally {
      setState(() => _actionLoading[id] = false);
    }
  }

  Future<void> _deleteSeries(Map<String, dynamic> series) async {
    final id = series['id'];
    if (_actionLoading[id] == true) return;
    final confirmed = await _showDeleteSheet(series['name']);
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading[id] = true);
    try {
      final resp = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=delete_series'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'series_id': id,
          'image_path': series['image_path'] ?? '',
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['status'] == 'success') {
          _showSnack('تم الحذف');
          _fetch();
        } else {
          _showSnack('فشل الحذف: ${data['message']}', error: true);
        }
      } else {
        _showSnack('HTTP ${resp.statusCode}', error: true);
      }
    } catch (e) {
      _showSnack('خطأ: $e', error: true);
    } finally {
      setState(() => _actionLoading[id] = false);
    }
  }

  Future<bool> _showDeleteSheet(String name) async {
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: false,
          builder: (ctx) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF262637),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE53E3E).withOpacity(0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFE53E3E),
                          size: 28,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'تأكيد الحذف',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'هل تريد حذف "$name"؟\nلا يمكن التراجع عن هذه العملية.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.35),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53E3E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  Future<void> _editSeries(Map<String, dynamic> series) async {
    final id = series['id'];
    if (_actionLoading[id] == true) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SeriesEditScreen(series: series)),
    );
    if (result == true) _fetch();
  }

  void _openEpisodes(Map<String, dynamic> series) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SeriesEpisodesScreen(series: series)),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool searching = _query.trim().isNotEmpty;
    final listData = searching ? _filtered : _series;
    return Scaffold(
      appBar: AppBar(title: const Text('المسلسلات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildSearchBar(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'خطأ: $_error',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    )
                  : listData.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            searching
                                ? 'لا توجد نتائج مطابقة'
                                : 'لا توجد مسلسلات',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: listData.length,
                      itemBuilder: (context, i) {
                        final series = listData[i];
                        final id = series['id'];
                        final busy = _actionLoading[id] == true;
                        return _SeriesListItem(
                          series: series,
                          busy: busy,
                          onTap: () => _openEpisodes(series),
                          onNotify: () => _sendSeriesNotification(series),
                          onEdit: () => _editSeries(series),
                          onDelete: () => _deleteSeries(series),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.35),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: Colors.white70, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث عن مسلسل...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                border: InputBorder.none,
              ),
              cursorColor: const Color(0xFF6C63FF),
            ),
          ),
          if (_query.trim().isNotEmpty)
            IconButton(
              tooltip: 'مسح',
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: () {
                _searchController.clear();
                _query = '';
                _applyFilter();
              },
            ),
        ],
      ),
    );
  }
}

class _SeriesListItem extends StatelessWidget {
  final Map<String, dynamic> series;
  final VoidCallback? onTap;
  final VoidCallback? onNotify;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool busy;
  const _SeriesListItem({
    required this.series,
    this.onTap,
    this.onNotify,
    this.onEdit,
    this.onDelete,
    this.busy = false,
  });

  String? get _posterFile => series['image_path']?.toString();
  String? get _posterUrl => _posterFile == null
      ? null
      : 'https://dramaxbox.bbs.tr/App/series_images/${series['image_path']}';

  @override
  Widget build(BuildContext context) {
    final name = series['name']?.toString() ?? 'بدون اسم';
    final episodes = series['episodes_count']?.toString() ?? '0';
    final description = series['description']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.09),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.25),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 70,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D44),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _posterUrl != null
                          ? Image.network(
                              _posterUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _circleBtn(
                              icon: Icons.notifications_active,
                              gradient: const [
                                Color(0xFF4CAF50),
                                Color(0xFF45A049),
                              ],
                              onTap: busy ? null : onNotify,
                              tooltip: 'إرسال إشعار',
                            ),
                            const SizedBox(width: 8),
                            _squareBtn(
                              icon: Icons.edit,
                              color: const Color(0xFF6C63FF),
                              onTap: busy ? null : onEdit,
                              tooltip: 'تعديل',
                            ),
                            const SizedBox(width: 8),
                            _squareBtn(
                              icon: Icons.delete,
                              color: const Color(0xFFE53E3E),
                              onTap: busy ? null : onDelete,
                              tooltip: 'حذف',
                            ),
                          ],
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF45A049),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'نشط',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$episodes حلقة',
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

  Widget _placeholder() =>
      const Icon(Icons.broken_image, color: Colors.white38);

  Widget _circleBtn({
    required IconData icon,
    required List<Color> gradient,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(22.5),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: busy && onTap != null
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, color: Colors.white, size: 22),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _squareBtn({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: busy && onTap != null
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(icon, color: color, size: 18),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }
}
