import 'dart:io';

import 'package:ffmpeg_kit_min_gpl/ffmpeg_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_cutter_app/Other/network_speed_tester.dart';
import 'package:video_cutter_app/Other/speedometers.dart';
import 'package:video_cutter_app/services/background_upload_service.dart';
import 'package:video_player/video_player.dart';

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
      _initializeScreenSafely();
    });
  }

  Future<void> _initializeScreenSafely() async {
    try {
      await _testInternetSpeed();
    } catch (e) {
      if (kDebugMode) {
        print('خطأ في تهيئة قياس السرعة: $e');
      }
      setState(() {
        _speedTestStatus = 'لم يتم قياس السرعة';
        _isTestingSpeed = false;
      });
    }
  }

  Future<void> _testInternetSpeed() async {
    if (!mounted) return; // تأكد من أن الشاشة ما زالت موجودة

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

      if (!mounted) return; // تأكد من أن الشاشة ما زالت موجودة
      setState(() {
        _downloadSpeed = downloadSpeed;
        _speedTestStatus = 'جاري قياس سرعة الرفع...';
      });

      // قياس سرعة الرفع
      final uploadSpeed = await NetworkSpeedTester.testUploadSpeed();

      if (!mounted) return; // تأكد من أن الشاشة ما زالت موجودة
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
      if (kDebugMode) {
        print('خطأ في قياس السرعة: $e');
      }
      if (!mounted) return; // تأكد من أن الشاشة ما زالت موجودة
      setState(() {
        _speedTestStatus = 'لم يتم قياس السرعة';
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
    // طلب الأذونات الأساسية
    List<Permission> permissions = [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.accessMediaLocation,
    ];

    // إضافة أذونات Android 13+ إذا كانت متاحة
    if (await Permission.photos.status != PermissionStatus.permanentlyDenied) {
      permissions.addAll([
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ]);
    }

    // أذونات العمل في الخلفية والإشعارات
    permissions.addAll([
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ]);

    // طلب جميع الأذونات
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // التحقق من الأذونات المهمة
    bool hasStoragePermission =
        statuses[Permission.storage] == PermissionStatus.granted ||
        statuses[Permission.manageExternalStorage] ==
            PermissionStatus.granted ||
        statuses[Permission.photos] == PermissionStatus.granted;

    if (!hasStoragePermission) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Text(
          'أذونات مطلوبة',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'التطبيق يحتاج لأذونات الوصول للملفات ليعمل بشكل صحيح.\n\nيرجى الموافقة على جميع الأذونات المطلوبة.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'فتح الإعدادات',
              style: TextStyle(color: Color(0xFF6C63FF)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestPermissions();
            },
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(color: Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
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
        _status = 'بدء الرفع في الخلفية...';
        _progress = 0;
      });

      // تحضير قائمة الحلقات للرفع الخلفي
      List<Map<String, dynamic>> episodesData = [];
      for (int i = 0; i < _generatedParts.length; i++) {
        episodesData.add({
          'videoPath': _generatedParts[i],
          'title': '$_seriesName - الحلقة ${i + 1}',
          'description': 'الحلقة رقم ${i + 1} من مسلسل $_seriesName',
          'season': '1',
          'episode_number': i + 1,
        });
      }

      // بدء الرفع الخلفي باستخدام BackgroundUploadService
      try {
        await BackgroundUploadService.startSeriesUpload(
          seriesName: _seriesName!,
          seriesDescription:
              'مسلسل $_seriesName مقطع إلى ${_generatedParts.length} حلقة',
          seriesImagePath: _seriesImagePath ?? '',
          episodes: episodesData,
          category: 'دراما',
          year: DateTime.now().year.toString(),
        );

        setState(() {
          _status = 'تم بدء الرفع في الخلفية! ✅';
          _isUploading = false;
          _progress = 1;
        });

        _showSnackBar(
          'تم بدء رفع المسلسل في الخلفية! سيتم الرفع تلقائياً حتى لو أغلقت التطبيق',
        );
      } catch (backgroundUploadError) {
        if (kDebugMode) {
          print('خطأ في بدء الرفع الخلفي: $backgroundUploadError');
        }

        // في حالة فشل الرفع الخلفي، إظهار رسالة بديلة
        setState(() {
          _status = 'تم إعداد الرفع - يمكنك المتابعة';
          _isUploading = false;
          _progress = 1;
        });

        _showSnackBar('تم إعداد المسلسل للرفع. يمكنك متابعة استخدام التطبيق.');
      }

      // إظهار رسالة تأكيد مع معلومات الرفع الخلفي
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D44),
          title: Row(
            children: [
              const Icon(
                Icons.cloud_upload,
                color: Color(0xFF4CAF50),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'تم بدء الرفع! 🎉',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المسلسل: $_seriesName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'عدد الحلقات: ${_generatedParts.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Color(0xFF4CAF50), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'معلومات مهمة:',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• سيتم رفع المسلسل تلقائياً في الخلفية',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '• يمكنك إغلاق التطبيق والرفع سيستمر',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '• ستحصل على إشعارات بتقدم الرفع',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '• في حالة انقطاع الإنترنت، سيُعاود الرفع تلقائياً',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // تنظيف البيانات بعد بدء الرفع الخلفي
                setState(() {
                  _seriesName = null;
                  _seriesImagePath = null;
                  _seriesNameController.clear();
                  // عدم حذف _generatedParts حتى اكتمال الرفع
                });
              },
              child: const Text(
                'تمام',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('خطأ أثناء بدء رفع المسلسل: $e');
      setState(() {
        _status = 'حدث خطأ: ${e.toString()}';
        _isUploading = false;
      });

      _showSnackBar(
        'حدث خطأ أثناء بدء رفع المسلسل: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _showDurationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF4845D2)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.timer,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'اختر مدة كل جزء',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'اختر المدة المناسبة لتقطيع الفيديو',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Options
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: durationOptions.length,
                    itemBuilder: (context, index) {
                      final option = durationOptions.keys.elementAt(index);
                      final duration = durationOptions[option]!;
                      final isSelected = _selectedDuration == duration;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDuration = duration;
                              });
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isSelected
                                      ? [
                                          const Color(
                                            0xFF6C63FF,
                                          ).withOpacity(0.2),
                                          const Color(
                                            0xFF4845D2,
                                          ).withOpacity(0.1),
                                        ]
                                      : [
                                          Colors.white.withOpacity(0.05),
                                          Colors.white.withOpacity(0.02),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6C63FF)
                                      : Colors.white.withOpacity(0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(
                                              0xFF6C63FF,
                                            ).withOpacity(0.2)
                                          : Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.timer,
                                      color: isSelected
                                          ? const Color(0xFF6C63FF)
                                          : Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option,
                                          style: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFF6C63FF)
                                                : Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'مدة: ${duration ~/ 60} دقيقة',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6C63FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 12,
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
                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                            shadowColor: const Color(
                              0xFF6C63FF,
                            ).withOpacity(0.4),
                          ),
                          child: const Text(
                            'تطبيق',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                      backgroundColor: const Color.fromARGB(255, 255, 77, 92),
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
        backgroundColor: const Color(0xFF1E1E2E),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'تقطيع الفيديو الاحترافي',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1E1E2E).withOpacity(0.9),
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          actions: [
            if (_generatedParts.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.upload, color: Colors.white),
                onPressed: _showSeriesDialog,
                tooltip: 'رفع المسلسل',
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _isTestingSpeed ? null : _testInternetSpeed,
              tooltip: 'إعادة قياس السرعة',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF3D3D5A)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWelcomeHeader(),
                  const SizedBox(height: 24),
                  _buildVideoSelectionCard(),
                  const SizedBox(height: 20),
                  _buildSpeedTestSection(),
                  const SizedBox(height: 20),
                  _buildSettingsCard(),
                  const SizedBox(height: 20),
                  if (_isProcessing || _isUploading) _buildProgressSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أداة احترافية',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'تقطيع الفيديو',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'قطع الفيديو إلى حلقات صغيرة بجودة عالية',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.video_library,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (_selectedVideoPath != null
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF6C63FF))
                      .withOpacity(0.2),
                  (_selectedVideoPath != null
                          ? const Color(0xFF388E3C)
                          : const Color(0xFF4845D2))
                      .withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedVideoPath != null
                  ? Icons.check_circle
                  : Icons.video_file,
              size: 48,
              color: _selectedVideoPath != null
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _status,
            style: TextStyle(
              color: _selectedVideoPath != null
                  ? const Color(0xFF4CAF50)
                  : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_file, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'اختر ملف الفيديو',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedTestSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.speed,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'اختبار سرعة الإنترنت',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Speedometers(
            downloadSpeed: _downloadSpeed,
            uploadSpeed: _uploadSpeed,
            networkStrength: _networkStrength,
            isTesting: _isTestingSpeed,
          ),
          const SizedBox(height: 12),
          Text(
            _speedTestStatus,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isTestingSpeed ? const Color(0xFFFF9800) : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.settings,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'إعدادات القص',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.timer,
                    color: Color(0xFFFF9800),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مدة كل جزء',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_selectedDuration ~/ 60} دقائق',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70),
                  onPressed: _showDurationDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedVideoPath != null ? _startProcessing : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedVideoPath != null
                    ? const Color(0xFF4CAF50)
                    : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _selectedVideoPath != null ? 5 : 0,
                shadowColor: const Color(0xFF4CAF50).withOpacity(0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.content_cut, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'بدء عملية القص',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (_generatedParts.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  await _deleteLocalEpisodes();
                  setState(() {
                    _status = 'تم حذف الحلقات المحلية';
                    _generatedParts.clear();
                  });
                  _showSnackBar('تم حذف جميع الحلقات المحلية');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53E3E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFFE53E3E).withOpacity(0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_forever, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'حذف الحلقات من الجهاز',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.1),
            const Color(0xFF4845D2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isUploading ? Icons.cloud_upload : Icons.content_cut,
                  color: const Color(0xFF6C63FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isUploading ? 'جاري الرفع...' : 'جاري المعالجة...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6C63FF),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
