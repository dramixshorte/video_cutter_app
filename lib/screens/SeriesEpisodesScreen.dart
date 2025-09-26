import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'EpisodePlayerScreen.dart';

class SeriesEpisodesScreen extends StatefulWidget {
  final Map<String, dynamic> series;

  const SeriesEpisodesScreen({super.key, required this.series});

  @override
  State<SeriesEpisodesScreen> createState() => _SeriesEpisodesScreenState();
}

class _SeriesEpisodesScreenState extends State<SeriesEpisodesScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _episodes = [];
  List<Map<String, dynamic>> _filteredEpisodes = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadEpisodes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=get_episodes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'series_id': widget.series['id']}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            // معالجة آمنة للبيانات
            final episodesData = data['episodes'] ?? [];
            _episodes = episodesData.map<Map<String, dynamic>>((episode) {
              return {
                'id': episode['id'],
                'series_id': episode['series_id'],
                'title': episode['title'] ?? 'حلقة بدون عنوان',
                'episode_number': episode['episode_number'] ?? 1,
                'video_path': episode['video_path'] ?? '',
                'created_at': episode['created_at'] ?? '',
                'description': 'الحلقة ${episode['episode_number'] ?? 1}',
              };
            }).toList();
            _filteredEpisodes = _episodes;
            _isLoading = false;
          });
          _animationController.forward();
        } else {
          setState(() => _isLoading = false);
          _showMessage(
            'فشل في تحميل الحلقات: ${data['message'] ?? 'خطأ غير معروف'}',
            isError: true,
          );
        }
      } else {
        setState(() => _isLoading = false);
        _showMessage('خطأ في الخادم: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('خطأ في تحميل الحلقات: $e', isError: true);
    }
  }

  void _filterEpisodes(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredEpisodes = _episodes;
      } else {
        _filteredEpisodes = _episodes.where((episode) {
          final title = episode['title']?.toString().toLowerCase() ?? '';
          final description =
              episode['description']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) ||
              description.contains(searchLower);
        }).toList();
      }
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError
            ? const Color(0xFFE53E3E)
            : const Color(0xFF4CAF50),
        duration: Duration(seconds: isError ? 4 : 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _editEpisodeTitle(Map<String, dynamic> episode) async {
    final TextEditingController titleController = TextEditingController();
    titleController.text = episode['title'] ?? '';

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF6C63FF), size: 24),
            SizedBox(width: 12),
            Text(
              'تعديل عنوان الحلقة',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: TextField(
          controller: titleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'عنوان الحلقة الجديد',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, titleController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (newTitle != null &&
        newTitle.isNotEmpty &&
        newTitle != episode['title']) {
      await _updateEpisodeTitle(episode, newTitle);
    }
  }

  Future<void> _updateEpisodeTitle(
    Map<String, dynamic> episode,
    String newTitle,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=update_episode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'episode_id': episode['id'], 'title': newTitle}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          _showMessage('تم تحديث عنوان الحلقة بنجاح! 🎉');
          _loadEpisodes(); // إعادة تحميل القائمة
        } else {
          _showMessage(
            'فشل في تحديث الحلقة: ${result['message']}',
            isError: true,
          );
        }
      } else {
        _showMessage('خطأ في الخادم: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('فشل في تحديث الحلقة: $e', isError: true);
    }
  }

  Future<void> _deleteEpisode(Map<String, dynamic> episode) async {
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
                  'حذف الحلقة',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'هل أنت متأكد من حذف الحلقة "${episode['title']}"؟\n\nسيتم حذف ملف الفيديو نهائياً.',
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
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=delete_episode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'episode_id': episode['id'],
          'video_path': episode['video_path'],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          _showMessage('تم حذف الحلقة بنجاح');
          _loadEpisodes(); // إعادة تحميل القائمة
        } else {
          _showMessage(
            'فشل في حذف الحلقة: ${result['message']}',
            isError: true,
          );
        }
      } else {
        _showMessage('خطأ في الخادم: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('فشل في حذف الحلقة: $e', isError: true);
    }
  }

  void _playEpisode(Map<String, dynamic> episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EpisodePlayerScreen(episode: episode, series: widget.series),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'حلقات ${widget.series['name']}',
          style: const TextStyle(
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
              onPressed: _loadEpisodes,
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
              Expanded(child: _buildEpisodesList()),
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
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.series['name'] ?? 'مسلسل',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'إدارة الحلقات والمحتوى',
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
    final totalEpisodes = _episodes.length;
    final filteredCount = _filteredEpisodes.length;

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
          _buildStatItem('المجموع', totalEpisodes, Icons.video_library),
          _buildStatItem('الظاهر', filteredCount, Icons.visibility),
          _buildStatItem('التشغيل', totalEpisodes, Icons.play_arrow),
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
        onChanged: _filterEpisodes,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'البحث في الحلقات...',
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
                    _filterEpisodes('');
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

  Widget _buildEpisodesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
        ),
      );
    }

    if (_filteredEpisodes.isEmpty) {
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
              _searchQuery.isNotEmpty ? 'لا توجد نتائج بحث' : 'لا توجد حلقات',
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
      itemCount: _filteredEpisodes.length,
      itemBuilder: (context, index) {
        final episode = _filteredEpisodes[index];
        return _buildEpisodeCard(episode, index);
      },
    );
  }

  Widget _buildEpisodeCard(Map<String, dynamic> episode, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playEpisode(episode),
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
                color: Colors.white.withOpacity(0.1),
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
                  // رقم الحلقة
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF4845D2)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        '${episode['episode_number'] ?? index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                                episode['title'] ?? 'حلقة بدون عنوان',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // زر التشغيل
                            GestureDetector(
                              onTap: () => _playEpisode(episode),
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
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
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // زر التعديل
                            GestureDetector(
                              onTap: () => _editEpisodeTitle(episode),
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
                              onTap: () => _deleteEpisode(episode),
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
                        if (episode['description'] != null &&
                            episode['description'].toString().isNotEmpty)
                          Text(
                            episode['description'].toString(),
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
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF45A049),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'متاح',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (episode['duration'] != null)
                              Text(
                                '${episode['duration']} دقيقة',
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
}
