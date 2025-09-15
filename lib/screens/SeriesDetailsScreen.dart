
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key});

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  List<Map<String, dynamic>> _seriesList = [];
  bool _isLoading = true;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _fetchSeries();
  }

  Future<void> _fetchSeries() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=get_all_series'),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // Convert each series map and ensure proper types
        final List<Map<String, dynamic>> seriesList = [];

        for (var series in data['data']) {
          seriesList.add({
            'id': int.tryParse(series['id'].toString()) ?? 0,
            'name': series['name'].toString(),
            'image_path': series['image_path'].toString(),
            'episodes_count':
                int.tryParse(series['episodes_count'].toString()) ?? 0,
          });
        }

        setState(() => _seriesList = seriesList);
      } else {
        _showSnackBar('فشل تحميل المسلسلات: ${data['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('خطأ في الاتصال: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _deleteSeries(int seriesId, String imagePath) async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=delete_series'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'series_id': seriesId, 'image_path': imagePath}),
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showSnackBar('تم حذف المسلسل بنجاح');
        _fetchSeries();
      } else {
        _showSnackBar('فشل حذف المسلسل: ${data['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('خطأ في الاتصال: ${e.toString()}', isError: true);
    }
  }

  void _showDeleteDialog(int seriesId, String seriesName, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المسلسل'),
        content: Text(
          'هل أنت متأكد من حذف المسلسل "$seriesName"؟ سيتم حذف جميع الحلقات والصور المرتبطة به.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _deleteSeries(seriesId, imagePath);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قائمة المسلسلات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchSeries,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchSeries,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _seriesList.length,
                  itemBuilder: (context, index) {
                    final series = _seriesList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SeriesDetailsScreen(
                                seriesId: series['id'],
                                seriesName: series['name'],
                                imagePath: series['image_path'],
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  'https://dramaxbox.bbs.tr/App/series_images/${series['image_path']}',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      series['name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'عدد الحلقات: ${series['episodes_count'] ?? 0}',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _showDeleteDialog(
                                  series['id'],
                                  series['name'],
                                  series['image_path'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class SeriesDetailsScreen extends StatefulWidget {
  final int seriesId;
  final String seriesName;
  final String imagePath;

  const SeriesDetailsScreen({
    super.key,
    required this.seriesId,
    required this.seriesName,
    required this.imagePath,
  });

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  List<Map<String, dynamic>> _episodes = [];
  bool _isLoading = true;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _fetchEpisodes(widget.seriesId);
  }

  Future<void> _fetchEpisodes(int seriesId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=get_episodes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'series_id': seriesId}),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        final List<Map<String, dynamic>> episodes = [];

        for (var episode in data['data']) {
          episodes.add({
            'id': int.tryParse(episode['id'].toString()) ?? 0,
            'title': episode['title'].toString(),
            'episode_number':
                int.tryParse(episode['episode_number'].toString()) ?? 0,
            'video_path': episode['video_path'].toString(),
          });
        }

        setState(() => _episodes = episodes);
      } else {
        _showSnackBar('فشل تحميل الحلقات: ${data['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('خطأ في الاتصال: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _deleteEpisode(int episodeId, String videoPath) async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=delete_episode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'episode_id': episodeId, 'video_path': videoPath}),
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showSnackBar('تم حذف الحلقة بنجاح');
        _fetchEpisodes(widget.seriesId);
      } else {
        _showSnackBar('فشل حذف الحلقة: ${data['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('خطأ في الاتصال: ${e.toString()}', isError: true);
    }
  }

  void _showEditEpisodeDialog(Map<String, dynamic> episode) {
    final titleController = TextEditingController(text: episode['title']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الحلقة'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'عنوان الحلقة',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateEpisodeTitle(episode['id'], titleController.text);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEpisodeTitle(int episodeId, String newTitle) async {
    try {
      final response = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=update_episode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'episode_id': episodeId, 'title': newTitle}),
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showSnackBar('تم تحديث عنوان الحلقة');
        _fetchEpisodes(widget.seriesId);
      } else {
        _showSnackBar('فشل تحديث الحلقة: ${data['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('خطأ في الاتصال: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.seriesName),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  _fetchEpisodes(widget.seriesId), // ✅ نمرر القيمة هنا
            ),
          ],
        ),

        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://dramaxbox.bbs.tr/App/series_images/${widget.imagePath}',
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey[800],
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _episodes.length,
                      itemBuilder: (context, index) {
                        final episode = _episodes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.play_circle_fill,
                              color: Colors.deepPurpleAccent,
                            ),
                            title: Text(episode['title']),
                            subtitle: Text(
                              'الحلقة ${episode['episode_number']}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _showEditEpisodeDialog(episode),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _deleteEpisode(
                                    episode['id'],
                                    episode['video_path'],
                                  ),
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
      ),
    );
  }
}