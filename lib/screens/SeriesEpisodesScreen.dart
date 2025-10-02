import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_cutter_app/widgets/app_toast.dart';
import 'dart:convert';
import 'EpisodePlayerScreen.dart';
// استبدلنا التوليد المباشر لاحقاً بخدمة مصغرات متعددة الاستراتيجيات + روابط موقعة
import 'package:video_cutter_app/services/thumbnail_service.dart';
import 'package:video_cutter_app/services/signed_url_service.dart';
import 'package:video_cutter_app/widgets/animated_progress_bar.dart';
// لم نعد نطلب إذن التخزين لأندرويد 10+ (Scoped Storage)، نحفظ في مساحة التطبيق
// أزلنا إذن التخزين؛ لم نعد نستخدم permission_handler هنا
import 'package:video_cutter_app/services/episode_downloader.dart';
import 'package:dio/dio.dart';
import 'dart:io';
// أزلنا percent_indicator لصالح AnimatedProgressBar المخصص

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
    final videoPath = episode['video_path']?.toString() ?? '';
    final localPath = episode['local_path']?.toString();
    if (videoPath.isEmpty && (localPath == null || localPath.isEmpty)) return;
    // طلب رابط موقّع للمصغرة (إن توفر backend يدعم mode=thumb)
    if (episode['signed_thumb_url'] == null) {
      try {
        final signed = await SignedUrlService.instance.getSignedUrl(
          episodeId: id is int ? id : int.parse(id.toString()),
          mode: 'thumb',
        );
        episode['signed_thumb_url'] = signed;
        setState(() {});
      } catch (_) {
        // تجاهل، سنحاول توليد محلي
      }
    }
    try {
      final bytes = await ThumbnailService.instance.getThumbnail(
        idKey: id.toString(),
        videoPath: videoPath,
        localPath: localPath,
      );
      setState(() => _thumbCache[id] = bytes);
    } catch (_) {
      setState(() => _thumbCache[id] = null);
    }
  }

  Future<void> _downloadEpisode(Map<String, dynamic> episode) async {
    final id = episode['id'];
    String rawPath = episode['video_path']?.toString() ?? '';
    if (rawPath.isEmpty) {
      _showMessage('لا يوجد ملف للتحميل', isError: true);
      return;
    }
    // جلب رابط موقّع
    String signedUrl;
    try {
      signedUrl = await SignedUrlService.instance.getSignedUrl(
        episodeId: id is int ? id : int.parse(id.toString()),
        mode: 'download',
      );
    } catch (e) {
      _showMessage('تعذر الحصول على رابط التحميل الآمن', isError: true);
      return;
    }
    final token = CancelToken();
    _downloadTokens[id] = token;
    setState(() => _downloadProgress[id] = 0.0);
    try {
      final localPath = await EpisodeDownloader.instance.downloadEpisode(
        url: signedUrl,
        id: id,
        cancelToken: token,
        onProgress: (p) => setState(() => _downloadProgress[id] = p),
      );
      _showMessage('تم التنزيل داخل التطبيق');
      episode['local_path'] = localPath;
      for (var i = 0; i < _episodes.length; i++) {
        if (_episodes[i]['id'] == id) {
          _episodes[i]['local_path'] = localPath;
          break;
        }
      }
      for (var i = 0; i < _filteredEpisodes.length; i++) {
        if (_filteredEpisodes[i]['id'] == id) {
          _filteredEpisodes[i]['local_path'] = localPath;
          break;
        }
      }
      setState(() {});
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

  Future<void> _playEpisode(Map<String, dynamic> episode) async {
    try {
      final ep = Map<String, dynamic>.from(episode);
      final local = ep['local_path']?.toString();
      if (local != null && local.isNotEmpty && File(local).existsSync()) {
        ep['video_path'] = local; // تشغيل محلي
      } else {
        // احصل على رابط بث موقّع آمن
        try {
          final signed = await SignedUrlService.instance.getSignedUrl(
            episodeId: ep['id'] is int
                ? ep['id']
                : int.parse(ep['id'].toString()),
            mode: 'stream',
          );
          ep['video_path'] = signed;
        } catch (e) {
          _showMessage('تعذر الحصول على رابط البث الآمن', isError: true);
          return;
        }
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EpisodePlayerScreen(episode: ep, series: widget.series),
        ),
      );
    } catch (_) {
      _showMessage('تعذر فتح مشغل الحلقة', isError: true);
    }
  }

  bool _hasLocalCopy(Map<String, dynamic> episode) {
    final p = episode['local_path']?.toString();
    if (p == null || p.isEmpty) return false;
    return File(p).existsSync();
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
                Builder(
                  builder: (ctx) {
                    final serverThumb =
                        (ep['thumbnail'] ?? ep['thumb'] ?? ep['poster_url'])
                            ?.toString() ??
                        '';
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
                            child: const Icon(
                              Icons.movie_outlined,
                              color: Colors.white24,
                            ),
                          );
                        },
                        loadingBuilder: (c, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 140,
                            height: 84,
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white24,
                              ),
                            ),
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
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Optional status chip (e.g., نشط)
                        if ((ep['status'] ?? '').toString().toLowerCase() ==
                            'active')
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'نشط',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              ep['title'] ?? 'حلقة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // اظهار شريط التقدم الاحترافي فقط عند التحميل
                      if (downloading) ...[
                        AnimatedProgressBar(
                          value: prog,
                          downloading: true,
                          completed: false,
                          semanticLabel: 'تحميل الحلقة',
                        ),
                        const SizedBox(height: 10),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _circleBtn(
                                color: const Color(0xFF6C63FF),
                                icon: Icons.play_arrow,
                                tooltip: 'تشغيل',
                                onTap: () => _playEpisode(ep),
                              ),
                              // عند التحميل، أظهر شريط التقدم الاحترافي داخل الأزرار
                              if (downloading)
                                SizedBox(
                                  width: 100,
                                  child: AnimatedProgressBar(
                                    value: prog,
                                    downloading: true,
                                    completed: false,
                                    semanticLabel: 'تحميل الحلقة',
                                  ),
                                )
                              else if (_hasLocalCopy(ep))
                                _circleBtn(
                                  color: Colors.green.shade600.withOpacity(
                                    0.25,
                                  ),
                                  icon: Icons.check,
                                  iconColor: Colors.greenAccent,
                                  tooltip:
                                      'محمل محلياً (اضغط مطول لإعادة التحميل)',
                                  onTap: () {},
                                  onLongPress: () => _downloadEpisode(ep),
                                )
                              else
                                _circleBtn(
                                  color: Colors.white12,
                                  icon: Icons.download,
                                  tooltip: 'تنزيل',
                                  onTap: () => _downloadEpisode(ep),
                                ),
                              _circleBtn(
                                color: Colors.white10,
                                icon: Icons.edit,
                                iconColor: Colors.white70,
                                tooltip: 'تعديل',
                                onTap: () => _editEpisodeTitle(ep),
                              ),
                              _circleBtn(
                                color: Colors.transparent,
                                icon: Icons.delete,
                                iconColor: Colors.redAccent,
                                tooltip: 'حذف',
                                onTap: () => _deleteEpisode(ep),
                              ),
                            ],
                          );
                        },
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

  Widget _circleBtn({
    required Color color,
    required IconData icon,
    Color? iconColor,
    String? tooltip,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
        ),
      ),
    );
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
