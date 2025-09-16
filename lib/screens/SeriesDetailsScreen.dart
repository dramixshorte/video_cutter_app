import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
        backgroundColor: Color(0xFF2D2D44),
        title: Text(
          'حذف المسلسل',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'هل أنت متأكد من حذف المسلسل "$seriesName"؟ سيتم حذف جميع الحلقات والصور المرتبطة به.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _deleteSeries(seriesId, imagePath);
            },
            child: Text('حذف'),
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
        backgroundColor: Color(0xFF1E1E2E),
        appBar: AppBar(
          title: Text(
            'قائمة المسلسلات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: Color(0xFF1E1E2E),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchSeries,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل المسلسلات...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchSeries,
                backgroundColor: Color(0xFF1E1E2E),
                color: Color(0xFF6C63FF),
                child: _seriesList.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد مسلسلات',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _seriesList.length,
                        itemBuilder: (context, index) {
                          final series = _seriesList[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
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
                                  padding: EdgeInsets.all(16),
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
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.broken_image, color: Colors.white70),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              series['name'],
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'عدد الحلقات: ${series['episodes_count'] ?? 0}',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
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
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          dialogBackgroundColor: Color(0xFF2D2D44),
        ),
        child: AlertDialog(
          title: Text(
            'تعديل الحلقة',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: titleController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'عنوان الحلقة',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6C63FF),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _updateEpisodeTitle(episode['id'], titleController.text);
              },
              child: Text('حفظ'),
            ),
          ],
        ),
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

  void _playEpisode(String videoPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: 'https://dramaxbox.bbs.tr/App/videos/$videoPath',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        backgroundColor: Color(0xFF1E1E2E),
        appBar: AppBar(
          title: Text(
            widget.seriesName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: Color(0xFF1E1E2E),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _fetchEpisodes(widget.seriesId),
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل الحلقات...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://dramaxbox.bbs.tr/App/series_images/${widget.imagePath}',
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Icon(Icons.broken_image, color: Colors.white70, size: 50),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _episodes.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد حلقات',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _episodes.length,
                            itemBuilder: (context, index) {
                              final episode = _episodes[index];
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
                                      Icons.play_circle_fill,
                                      color: Color(0xFF6C63FF),
                                    ),
                                  ),
                                  title: Text(
                                    episode['title'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'الحلقة ${episode['episode_number']}',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.play_arrow, color: Colors.green),
                                        onPressed: () => _playEpisode(episode['video_path']),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _showEditEpisodeDialog(episode),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete, color: Colors.redAccent),
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

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Color(0xFF6C63FF),
          handleColor: Color(0xFF6C63FF),
          backgroundColor: Colors.white54,
          bufferedColor: Colors.white24,
        ),
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
      );

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing video player: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تشغيل الفيديو'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            )
          : Center(
              child: Chewie(controller: _chewieController),
            ),
    );
  }
}