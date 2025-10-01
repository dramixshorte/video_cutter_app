import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_cutter_app/widgets/app_toast.dart';
import 'dart:convert';
import 'EpisodePlayerScreen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:typed_data';

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
  final Map<dynamic, Uint8List?> _thumbCache = {};
  final Map<dynamic, double> _downloadProgress = {};
  final Map<dynamic, CancelToken> _downloadTokens = {};

  bool _isLoading = true;
  late AnimationController _animationController;
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
    for (var t in _downloadTokens.values) {
      if (!t.isCancelled) t.cancel();
    }
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _isLoading = true);
    try {
      final resp = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=get_episodes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'series_id': widget.series['id']}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['status'] == 'success') {
          final list = (data['episodes'] ?? []) as List<dynamic>;
          _episodes = list.map<Map<String, dynamic>>((e) {
            return {
              'id': e['id'],
              'title': e['title'] ?? 'حلقة',
              'video_path': e['video_path'] ?? '',
              'description': e['description'] ?? '',
              'duration': e['duration'],
              'progress': e['progress'],
            };
          }).toList();
          _filteredEpisodes = List.from(_episodes);

          for (var i = 0; i < _episodes.length && i < 6; i++) {
            _generateThumbnail(_episodes[i]);
          }
        }
      }
    } catch (e) {
      _showMessage('فشل في تحميل الحلقات: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateThumbnail(Map<String, dynamic> episode) async {
    final id = episode['id'];
    if (_thumbCache.containsKey(id)) return;
    final path = episode['video_path']?.toString() ?? '';
    if (path.isEmpty) return;
    try {
      // Try direct thumbnail generation first (works for local files and some URLs)
      Uint8List? bytes;
      try {
        bytes = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.PNG,
          maxWidth: 512,
          quality: 75,
        );
      } catch (_) {
        bytes = null;
      }

      // If direct generation failed and the path is an HTTP URL, try fetching a small range
      if (bytes == null &&
          (path.startsWith('http://') || path.startsWith('https://'))) {
        try {
          final tmp = await getTemporaryDirectory();
          final tmpFile = File('${tmp.path}/ep_thumb_$id');
          // Try to request the first ~200KB using Range header (server must support it)
          final resp = await http.get(
            Uri.parse(path),
            headers: {'Range': 'bytes=0-200000'},
          );
          if (resp.statusCode == 200 || resp.statusCode == 206) {
            await tmpFile.writeAsBytes(resp.bodyBytes, flush: true);
            try {
              bytes = await VideoThumbnail.thumbnailData(
                video: tmpFile.path,
                imageFormat: ImageFormat.PNG,
                maxWidth: 512,
                quality: 75,
              );
            } catch (_) {
              bytes = null;
            }
          }
          if (await tmpFile.exists()) await tmpFile.delete();
        } catch (_) {
          // ignore network/thumb failures
        }
      }

      setState(() => _thumbCache[id] = bytes);
    } catch (_) {
      setState(() => _thumbCache[id] = null);
    }
  }

  double _normalizeProgress(dynamic p) {
    if (p == null) return 0.0;
    if (p is double) return p.clamp(0.0, 1.0);
    if (p is int) return (p > 1) ? (p.clamp(0, 100) / 100) : p.toDouble();
    final s = p.toString();
    final d = double.tryParse(s);
    if (d != null) return d > 1 ? (d.clamp(0, 100) / 100) : d;
    return 0.0;
  }

  Future<void> _downloadEpisode(Map<String, dynamic> episode) async {
    final id = episode['id'];
    final url = episode['video_path']?.toString() ?? '';
    if (url.isEmpty) {
      _showMessage('لا يوجد ملف للتحميل', isError: true);
      return;
    }

    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showMessage('مطلوب إذن التخزين', isError: true);
        return;
      }
    }

    String savePath;
    try {
      if (Platform.isAndroid) {
        final ext = await getExternalStorageDirectory();
        final base = ext?.path.split('/Android').first ?? '';
        final dir = Directory('$base/Download');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        // preserve original extension if present
        String fileExt = 'mp4';
        try {
          final uri = Uri.parse(url);
          final fname = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : '';
          if (fname.contains('.')) fileExt = fname.split('.').last;
        } catch (_) {}
        savePath = '${dir.path}/episode_$id.$fileExt';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        String fileExt = 'mp4';
        try {
          final uri = Uri.parse(url);
          final fname = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : '';
          if (fname.contains('.')) fileExt = fname.split('.').last;
        } catch (_) {}
        savePath = '${dir.path}/episode_$id.$fileExt';
      }
    } catch (e) {
      final dir = await getApplicationDocumentsDirectory();
      savePath = '${dir.path}/episode_$id.mp4';
    }

    final dio = Dio();
    final token = CancelToken();
    _downloadTokens[id] = token;
    setState(() => _downloadProgress[id] = 0.0);

    try {
      await dio.download(
        url,
        savePath,
        cancelToken: token,
        onReceiveProgress: (r, t) {
          if (t > 0) setState(() => _downloadProgress[id] = r / t);
        },
      );
      _showMessage('تم الحفظ: $savePath');
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        _showMessage('تم إلغاء التحميل');
      } else {
        _showMessage('فشل التحميل: $e', isError: true);
      }
    } finally {
      _downloadProgress.remove(id);
      _downloadTokens.remove(id);
      setState(() {});
    }
  }

  void _cancelDownload(dynamic id) {
    final t = _downloadTokens[id];
    if (t != null && !t.isCancelled) t.cancel();
  }

  void _filterEpisodes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredEpisodes = List.from(_episodes);
      } else {
        _filteredEpisodes = _episodes.where((e) {
          final title = e['title']?.toString().toLowerCase() ?? '';
          return title.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showMessage(String m, {bool isError = false}) {
    try {
      AppToast.show(
        context,
        m,
        type: isError ? ToastType.error : ToastType.success,
      );
    } catch (_) {
      // fallback: simple snackbar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  void _playEpisode(Map<String, dynamic> episode) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EpisodePlayerScreen(episode: episode, series: widget.series),
        ),
      );
    } catch (_) {
      _showMessage('تعذر فتح مشغل الحلقة', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'حلقات ${widget.series['name']}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterEpisodes,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'البحث في الحلقات...',
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF6C63FF),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            _filterEpisodes('');
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredEpisodes.isEmpty) {
      return const Center(
        child: Text('لا توجد حلقات', style: TextStyle(color: Colors.white)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredEpisodes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final ep = _filteredEpisodes[i];
        final id = ep['id'];
        final downloading = _downloadProgress.containsKey(id);
        final prog = _downloadProgress[id] ?? 0.0;

        // If we don't yet have a thumbnail cached for this episode, start generation
        if (!_thumbCache.containsKey(id) &&
            (ep['video_path']?.toString() ?? '').isNotEmpty) {
          Future.microtask(() => _generateThumbnail(ep));
        }

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A2A3A), Color(0xFF23232B)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Thumbnail: prefer server-provided thumbnail fields, otherwise fall back to generated thumb
                Builder(builder: (ctx) {
                  final serverThumb = (ep['thumbnail'] ?? ep['thumb'] ?? ep['poster_url'])?.toString() ?? '';
                  Widget img;
                  if (serverThumb.isNotEmpty) {
                    img = Image.network(
                      serverThumb,
                      width: 140,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        if (_thumbCache[id] != null) {
                          return Image.memory(
                            _thumbCache[id]!,
                            width: 140,
                            height: 84,
                            fit: BoxFit.cover,
                          );
                        }
                        return Container(
                          width: 140,
                          height: 84,
                          color: Colors.black26,
                          child: const Icon(Icons.movie_outlined, color: Colors.white24),
                        );
                      },
                      loadingBuilder: (c, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 140,
                          height: 84,
                          color: Colors.black26,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                        );
                      },
                    );
                  } else if (_thumbCache[id] != null) {
                    img = Image.memory(
                      _thumbCache[id]!,
                      width: 140,
                      height: 84,
                      fit: BoxFit.cover,
                    );
                  } else {
                    img = Container(
                      width: 140,
                      height: 84,
                      color: Colors.black26,
                      child: const Icon(
                        Icons.movie_outlined,
                        color: Colors.white24,
                      ),
                    );
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: img,
                      ),
                      // Play overlay
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _playEpisode(ep),
                            borderRadius: BorderRadius.circular(8),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Optional status chip (e.g., نشط)
                      if ((ep['status'] ?? '').toString().toLowerCase() == 'active')
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('نشط', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ep['title'] ?? 'حلقة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearPercentIndicator(
                        lineHeight: 8.0,
                        percent: _normalizeProgress(ep['progress']),
                        backgroundColor: Colors.white12,
                        progressColor: const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 8),

                      // Horizontal action row: Play | Download (or progress) | Edit | Delete
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Play (icon only)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                              onPressed: () => _playEpisode(ep),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Download (icon only) or inline progress
                          downloading
                              ? SizedBox(
                                  width: 130,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: LinearPercentIndicator(
                                          lineHeight: 6.0,
                                          percent: prog,
                                          backgroundColor: Colors.white12,
                                          progressColor: Colors.lightBlueAccent,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _cancelDownload(id),
                                        icon: const Icon(Icons.cancel, color: Colors.white70, size: 20),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.download, color: Colors.white, size: 20),
                                    onPressed: () => _downloadEpisode(ep),
                                  ),
                                ),
                          const SizedBox(width: 10),

                          // Edit (icon only)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                              onPressed: () => _editEpisodeTitle(ep),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Delete (icon only)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                              onPressed: () => _deleteEpisode(ep),
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
        );
      },
    );
  }

  Future<void> _editEpisodeTitle(Map<String, dynamic> episode) async {
    final controller = TextEditingController(text: episode['title'] ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Text(
          'تعديل عنوان الحلقة',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
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
          _showMessage('تم تحديث عنوان الحلقة');
          _loadEpisodes();
        } else {
          _showMessage(
            'فشل في تحديث الحلقة: ${result['message']}',
            isError: true,
          );
        }
      }
    } catch (e) {
      _showMessage('فشل في تحديث الحلقة: $e', isError: true);
    }
  }

  Future<void> _deleteEpisode(Map<String, dynamic> episode) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D44),
            title: const Text(
              'تأكيد الحذف',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'هل تريد حذف الحلقة "${episode['title']}"؟',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      final resp = await http.post(
        Uri.parse('https://dramaxbox.bbs.tr/App/api.php?action=delete_episode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'episode_id': episode['id'],
          'video_path': episode['video_path'],
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['status'] == 'success') {
          _showMessage('تم حذف الحلقة');
          _loadEpisodes();
        } else {
          _showMessage('فشل في حذف الحلقة: ${data['message']}', isError: true);
        }
      }
    } catch (e) {
      _showMessage('فشل في حذف الحلقة: $e', isError: true);
    }
  }
}
