import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SeriesManagementScreen extends StatefulWidget {
  const SeriesManagementScreen({super.key});

  @override
  State<SeriesManagementScreen> createState() => _SeriesManagementScreenState();
}

class _SeriesManagementScreenState extends State<SeriesManagementScreen> {
  List<dynamic> _series = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=get_all_series'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _series = data['data'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل المسلسلات: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text(
          'إدارة المسلسلات',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2D2D44),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF3D3D5A)],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                ),
              )
            : _series.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد مسلسلات',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadSeries,
                color: const Color(0xFF6C63FF),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _series.length,
                  itemBuilder: (context, index) {
                    final series = _series[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
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
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child:
                              series['image_path'] != null &&
                                  series['image_path'].isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    'https://dramaxbox.bbs.tr/App/series_images/${series['image_path']}',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.movie,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                  ),
                                )
                              : const Icon(
                                  Icons.movie,
                                  color: Colors.white,
                                  size: 30,
                                ),
                        ),
                        title: Text(
                          series['name'] ?? 'بدون اسم',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'عدد الحلقات: ${series['episodes_count'] ?? 0}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                        onTap: () {
                          // يمكن إضافة تنقل لصفحة تفاصيل المسلسل هنا
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم النقر على: ${series['name']}'),
                              backgroundColor: const Color(0xFF6C63FF),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
