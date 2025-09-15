import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_min_gpl/ffmpeg_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_cutter_app/dashboard_screen.dart';
import 'package:video_cutter_app/network_speed_tester.dart';
import 'package:video_cutter_app/speedometers.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:flutter_background/flutter_background.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "جاري رفع الحلقات",
    notificationText: "التطبيق يعمل في الخلفية",
    notificationImportance: AndroidNotificationImportance.high,
  );

  final hasPermissions = await FlutterBackground.initialize(
    androidConfig: androidConfig,
  );

  if (hasPermissions) {
    await FlutterBackground.enableBackgroundExecution();
  }
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await WakelockPlus.enable();

  runApp(const VideoCutterApp());
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'upload_episode_task':
        break;
      case 'show_upload_complete_notification':
        break;
      case 'show_upload_failed_notification':
        break;
    }
    return true;
  });
}

class VideoCutterApp extends StatelessWidget {
  const VideoCutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدير المسلسلات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.tealAccent,
          surface: const Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: const Color(0xFF1E1E1E),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurpleAccent,
          elevation: 4,
          centerTitle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurpleAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SeriesListScreen(),
    const VideoCutterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.local_movies), // ✅ اسم أيقونة صحيح
            label: 'المسلسلات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'قص الفيديو',
          ),
        ],
      ),
    );
  }
}

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

class VideoCutterScreen extends StatefulWidget {
  const VideoCutterScreen({super.key});

  @override
  State<VideoCutterScreen> createState() => _VideoCutterScreenState();
}

class _VideoCutterScreenState extends State<VideoCutterScreen> {
  double _downloadSpeed = 0;
  double _uploadSpeed = 0;
  double _networkStrength = 0; // قيمة من 0 إلى 1
  bool _isTestingSpeed = false;

  String _speedTestStatus = 'انقر لقياس السرعة';

  bool _isProcessing = false;
  bool _isUploading = false;
  String _status = 'اضغط لاختيار الفيديو';
  int _totalParts = 0;
  int _currentPart = 0;
  double _progress = 0;
  String? _selectedVideoPath;
  final List<String> _generatedParts = [];
  String? _seriesName;
  String? _seriesImagePath;
  int _selectedDuration = 120;

  final TextEditingController _seriesNameController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  static const String apiUrl = 'https://dramaxbox.bbs.tr/App/api.php';

  final Map<String, int> durationOptions = {
    '3 دقائق': 180,
    '5 دقائق': 300,
    '7 دقائق': 420,
    '10 دقائق': 600,
    '15 دقائق': 900,
    'دقيقة واحدة': 60,
    'دقيقتين': 120,
  };

  @override
  void initState() {
    super.initState();
    // بدء قياس السرعة تلقائياً عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testInternetSpeed();
    });
  }

  Future<void> _testInternetSpeed() async {
    setState(() {
      _isTestingSpeed = true;
      _speedTestStatus = 'جاري قياس سرعة التحميل...';
      _downloadSpeed = 0;
      _uploadSpeed = 0;
      _networkStrength = 0;
    });

    try {
      // قياس سرعة التحميل
      final downloadSpeed = await NetworkSpeedTester.testDownloadSpeed();

      setState(() {
        _downloadSpeed = downloadSpeed;
        _speedTestStatus = 'جاري قياس سرعة الرفع...';
      });

      // قياس سرعة الرفع
      final uploadSpeed = await NetworkSpeedTester.testUploadSpeed();

      setState(() {
        _uploadSpeed = uploadSpeed;
        _speedTestStatus = 'تم قياس السرعة';
        _isTestingSpeed = false;
        _networkStrength = NetworkSpeedTester.calculateNetworkStrength(
          _downloadSpeed,
          _uploadSpeed,
        );
      });
    } catch (e) {
      setState(() {
        _speedTestStatus = 'فشل قياس السرعة: $e';
        _isTestingSpeed = false;
      });
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

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.accessMediaLocation, // إضافة صلاحية جديدة
    ].request();
  }

  Future<String> _getSaveDirectory() async {
    try {
      final dir = Directory('/storage/emulated/0/Download/VideoCutter');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } catch (e) {
      if (kDebugMode) {
        print('Directory Error: $e');
      }
      throw Exception('تعذر إنشاء مجلد الحفظ');
    }
  }

  Future<double> _getVideoDuration(String path) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      return duration.inSeconds.toDouble();
    } catch (e) {
      if (kDebugMode) {
        print('Video Player Duration Error: $e');
      }

      try {
        final session = await FFmpegKit.execute(
          '-i "$path" -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1',
        );
        final output = await session.getOutput();
        return double.tryParse(output?.trim() ?? '0') ?? 0;
      } catch (e) {
        if (kDebugMode) {
          print('FFmpeg Duration Error: $e');
        }
        throw Exception('تعذر قراءة مدة الفيديو');
      }
    }
  }

  Future<void> _cutVideoSegment({
    required String inputPath,
    required String outputPath,
    required int start,
    required int duration,
  }) async {
    try {
      final command = [
        '-y',
        '-ss',
        start.toString(),
        '-i',
        inputPath,
        '-t',
        duration.toString(),
        '-c',
        'copy',
        '-avoid_negative_ts',
        '1',
        outputPath,
      ];

      if (kDebugMode) {
        print('Executing: ffmpeg ${command.join(' ')}');
      }

      final session = await FFmpegKit.executeWithArguments(command);
      final returnCode = await session.getReturnCode();

      if (returnCode == null || !returnCode.isValueSuccess()) {
        final logs = await session.getAllLogsAsString();
        throw Exception('فشل قص الجزء: ${logs ?? 'خطأ غير معروف'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('FFmpeg Execution Error: $e');
      }
      rethrow;
    }
  }

  Future<void> _selectVideo() async {
    try {
      await _requestPermissions();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _status = 'لم يتم اختيار ملف');
        return;
      }

      setState(() {
        _selectedVideoPath = result.files.single.path!;
        _status = 'تم اختيار الفيديو: ${_selectedVideoPath!.split('/').last}';
        _generatedParts.clear();
      });
    } catch (e) {
      setState(() => _status = 'خطأ في الصلاحيات: $e');
      _showSnackBar('خطأ في الصلاحيات: $e', isError: true);
      await openAppSettings();
    }
  }

  Future<void> _selectImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _seriesImagePath = result.files.single.path!;
        });
        _showSnackBar('تم اختيار صورة المسلسل');
      }
    } catch (e) {
      setState(() => _status = 'خطأ في اختيار الصورة: $e');
      _showSnackBar('خطأ في اختيار الصورة: $e', isError: true);
    }
  }

  Future<void> _startProcessing() async {
    if (_selectedVideoPath == null) {
      setState(() => _status = 'لم يتم اختيار فيديو');
      _showSnackBar('الرجاء اختيار فيديو أولاً', isError: true);
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _status = 'جاري التحضير...';
        _progress = 0;
        _generatedParts.clear();
      });

      final file = File(_selectedVideoPath!);
      if (!await file.exists()) {
        throw Exception('الملف غير موجود');
      }

      final saveDir = await _getSaveDirectory();
      final duration = await _getVideoDuration(_selectedVideoPath!);

      if (duration <= 0) {
        throw Exception('مدة الفيديو غير صالحة');
      }

      final segmentDuration = _selectedDuration;
      _totalParts = (duration / segmentDuration).ceil();

      setState(() => _status = 'جاري معالجة الفيديو...');
      _showSnackBar('بدأت عملية قص الفيديو إلى أجزاء');

      for (int i = 0; i < _totalParts; i++) {
        final start = i * segmentDuration;
        final remaining = duration - start;
        final currentDuration = remaining < segmentDuration
            ? remaining
            : segmentDuration;

        final outputPath =
            '${saveDir.trim()}/part_${i + 1}.mp4'; // إزالة المسافات من المسار فقط
        setState(() {
          _currentPart = i + 1;
          _progress = _currentPart / _totalParts;
          _status = 'جاري قص الجزء $_currentPart/$_totalParts';
        });

        await _cutVideoSegment(
          inputPath: _selectedVideoPath!,
          outputPath: outputPath,
          start: start,
          duration: currentDuration.toInt(),
        );

        _generatedParts.add(outputPath);
      }

      setState(() {
        _status = 'تم الانتهاء! $_totalParts أجزاء في مجلد التنزيلات';
        _isProcessing = false;
      });
      _showSnackBar('تم قص الفيديو بنجاح إلى $_totalParts أجزاء');
    } catch (e) {
      setState(() {
        _status = 'حدث خطأ: ${e.toString()}';
        _isProcessing = false;
      });
      _showSnackBar('حدث خطأ أثناء قص الفيديو: ${e.toString()}', isError: true);
      if (kDebugMode) {
        print('Processing Error: $e');
      }
    }
  }

  Future<void> _uploadSeries() async {
    if (_seriesName == null || _seriesName!.isEmpty) {
      setState(() => _status = 'الرجاء إدخال اسم المسلسل');
      _showSnackBar('الرجاء إدخال اسم المسلسل', isError: true);
      return;
    }

    if (_generatedParts.isEmpty) {
      setState(() => _status = 'لا توجد حلقات لرفعها');
      _showSnackBar('لا توجد حلقات لرفعها', isError: true);
      return;
    }

    try {
      setState(() {
        _isUploading = true;
        _status = 'جاري رفع المسلسل...';
        _progress = 0;
      });
      _showSnackBar('بدأت عملية رفع المسلسل');

      String? imageUrl;
      if (_seriesImagePath != null) {
        final imageFile = File(_seriesImagePath!);

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$apiUrl?action=upload_image'),
        );

        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            filename: path.basename(imageFile.path),
          ),
        );

        var response = await request.send();
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);

        if (json['status'] != 'success') {
          throw Exception('فشل رفع صورة المسلسل: ${json['message']}');
        }
        imageUrl = json['image_path'];
        _showSnackBar('تم رفع صورة المسلسل بنجاح');
      }

      var createResponse = await http.post(
        Uri.parse('$apiUrl?action=create_series'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': _seriesName!, 'image_path': imageUrl ?? ''}),
      );

      var createData = jsonDecode(createResponse.body);
      if (createData['status'] != 'success') {
        throw Exception('فشل إنشاء المسلسل: ${createData['message']}');
      }

      final seriesId = createData['series_id'];
      _showSnackBar('تم إنشاء المسلسل في قاعدة البيانات');

      for (int i = 0; i < _generatedParts.length; i++) {
        final episodeNumber = i + 1;
        final episodeFile = File(_generatedParts[i]);

        setState(() {
          _status = 'جاري رفع الحلقة $episodeNumber/${_generatedParts.length}';
          _progress = episodeNumber / _generatedParts.length;
        });

        _showSnackBar(
          'جاري رفع الحلقة $episodeNumber/${_generatedParts.length}',
        );

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$apiUrl?action=upload_episode'),
        );

        request.fields['series_id'] = seriesId.toString();
        request.fields['episode_number'] = episodeNumber.toString();
        request.fields['title'] = '$_seriesName - الحلقة $episodeNumber';

        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            episodeFile.path,
            filename:
                'episode_$episodeNumber.${path.extension(episodeFile.path).replaceAll(".", "")}',
          ),
        );

        var response = await request.send();
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);

        if (json['status'] != 'success') {
          throw Exception('فشل رفع الحلقة $episodeNumber: ${json['message']}');
        }
      }

      setState(() {
        _status = 'تم رفع المسلسل "$_seriesName" بنجاح!';
        _isUploading = false;
        _progress = 1;
        _seriesName = null;
        _seriesImagePath = null;
        _seriesNameController.clear();
        _generatedParts.clear();
      });

      _showSnackBar('تم رفع المسلسل "$_seriesName" بنجاح!');
    } catch (e) {
      debugPrint('خطأ أثناء رفع المسلسل: $e');
      setState(() {
        _status = 'حدث خطأ: ${e.toString()}';
        _isUploading = false;
      });

      _showSnackBar(
        'حدث خطأ أثناء رفع المسلسل: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _showDurationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'اختر مدة كل جزء',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: durationOptions.length,
                    itemBuilder: (context, index) {
                      final option = durationOptions.keys.elementAt(index);
                      return Card(
                        color: const Color(0xFF2D2D2D),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: RadioListTile<int>(
                          title: Text(
                            option,
                            style: const TextStyle(color: Colors.white),
                          ),
                          value: durationOptions[option]!,
                          groupValue: _selectedDuration,
                          onChanged: (value) {
                            setState(() {
                              _selectedDuration = value!;
                            });
                            Navigator.of(context).pop();
                          },
                          activeColor: Colors.tealAccent,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteLocalEpisodes() async {
    try {
      for (final episodePath in _generatedParts) {
        try {
          final file = File(episodePath);
          if (await file.exists()) {
            await file.delete();
            if (kDebugMode) {
              print('تم حذف الحلقة المحلية: $episodePath');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('خطأ في حذف الحلقة $episodePath: $e');
          }
        }
      }
      _generatedParts.clear();
    } catch (e) {
      if (kDebugMode) {
        print('خطأ عام في حذف الحلقات: $e');
      }
      rethrow;
    }
  }

  void _showSeriesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'إضافة مسلسل جديد',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _seriesNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المسلسل',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _seriesName = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _selectImage,
                    icon: const Icon(Icons.image),
                    label: const Text('اختر صورة للمسلسل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_seriesImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'تم اختيار الصورة: ${_seriesImagePath!.split('/').last}',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _uploadSeries();
                        },
                        child: const Text('رفع المسلسل'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قص الفيديو'),
          actions: [
            if (_generatedParts.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.upload),
                onPressed: _showSeriesDialog,
              ),

            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isTestingSpeed ? null : _testInternetSpeed,
              tooltip: 'إعادة قياس السرعة',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.video_library,
                        size: 48,
                        color: Colors.deepPurpleAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: TextStyle(
                          color: _selectedVideoPath != null
                              ? Colors.tealAccent
                              : Colors.white70,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _selectVideo,
                        icon: const Icon(Icons.video_file),
                        label: const Text('اختر ملف الفيديو'),
                      ),
                    ],
                  ),
                ),
              ),
              Speedometers(
                downloadSpeed: _downloadSpeed,
                uploadSpeed: _uploadSpeed,
                networkStrength: _networkStrength,
                isTesting: _isTestingSpeed,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _speedTestStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isTestingSpeed ? Colors.amber : Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إعدادات القص',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.timer),
                        title: Text(
                          'مدة كل جزء: ${_selectedDuration ~/ 60} دقائق',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: _showDurationDialog,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectedVideoPath != null
                              ? _startProcessing
                              : null,
                          icon: const Icon(Icons.content_cut),
                          label: const Text('بدء عملية القص'),
                        ),
                      ),
                      if (_generatedParts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _deleteLocalEpisodes();
                              setState(() {
                                _status = 'تم حذف الحلقات المحلية';
                                _generatedParts.clear();
                              });
                              _showSnackBar('تم حذف جميع الحلقات المحلية');
                            },
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('حذف الحلقات من الجهاز'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_isProcessing || _isUploading) ...[
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[800],
                  color: Colors.deepPurpleAccent,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
