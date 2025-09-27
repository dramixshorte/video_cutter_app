import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_cutter_app/widgets/app_toast.dart';
// Removed unused dio & convert imports after migrating to UploadManager
import 'package:video_cutter_app/services/upload_manager.dart';
import 'package:video_cutter_app/services/video_processing.dart';
// NOTE: تم تعطيل ProDialog هنا لعزل سبب التجمّد في الحوارات المخصصة

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VideoCutterScreen extends StatefulWidget {
  const VideoCutterScreen({super.key});

  @override
  State<VideoCutterScreen> createState() => _VideoCutterScreenState();
}

class _VideoCutterScreenState extends State<VideoCutterScreen> {
  // حالة تخص فقط عملية القص المحلية (لا تشمل الرفع بعد نقل الرفع لـ UploadManager)
  bool _isProcessing = false;
  String _status = 'اضغط لاختيار الفيديو';
  int _totalParts = 0;
  double _progress = 0; // تقدم القص المحلي فقط
  String? _selectedVideoPath;
  final List<String> _generatedParts = [];
  String? _seriesName;
  String? _seriesImagePath;
  String? _compressedSeriesImagePath;
  int? _originalImageSize;
  int? _compressedImageSize;
  int _selectedDuration = 120;
  bool _randomMode = false; // وضع القص العشوائي (90-120 ثانية)
  bool _isCleaning = false; // لمنع نقرات متعددة أثناء التنظيف
  bool _dialogOpen = false; // منع فتح أكثر من حوار في نفس الوقت
  int? _partsTarget; // عدد الأجزاء المتوقع (للوضع الثابت)

  final TextEditingController _seriesNameController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  // خيارات مدة القص (دقائق -> ثواني)
  final Map<String, int> durationOptions = const {
    'دقيقتان': 120,
    '3 دقائق': 180,
    '5 دقائق': 300,
    '7 دقائق': 420,
    '10 دقائق': 600,
  };

  void _showSnackBar(String message, {bool isError = false}) {
    AppToast.show(
      context,
      message,
      type: isError ? ToastType.error : ToastType.success,
    );
  }

  Future<void> _requestPermissions() async {
    try {
      // طلب الأذونات الأساسية أولاً
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
        Permission.photos,
        Permission.videos,
        Permission.mediaLibrary,
      ].request();

      // فحص إذا كان هناك أذونات مرفوضة
      bool hasdenied = statuses.values.any(
        (status) => status.isDenied || status.isPermanentlyDenied,
      );

      if (hasdenied) {
        // محاولة ثانية للأذونات المهمة
        if (await Permission.manageExternalStorage.isDenied) {
          final status = await Permission.manageExternalStorage.request();
          if (status.isPermanentlyDenied) {
            _showPermissionDialog();
            return;
          }
        }

        // طلب أذونات إضافية لـ Android 13+
        if (Platform.isAndroid) {
          await [
            Permission.videos,
            Permission.audio,
            Permission.photos,
          ].request();
        }
      }

      // فحص نهائي للأذونات المطلوبة
      final storageStatus = await Permission.storage.status;
      final manageStatus = await Permission.manageExternalStorage.status;

      if (storageStatus.isDenied || manageStatus.isDenied) {
        _showSnackBar('يرجى منح جميع الأذونات المطلوبة للتطبيق', isError: true);
      } else {
        _showSnackBar('تم منح الأذونات بنجاح', isError: false);
      }
    } catch (e) {
      _showSnackBar('خطأ في طلب الأذونات: $e', isError: true);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('أذونات مطلوبة'),
        content: const Text(
          'هذا التطبيق يحتاج لأذونات التخزين للعمل بشكل صحيح.\n'
          'يرجى منح الأذونات من الإعدادات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  // ===================== رفع المسلسل (Dio) =====================
  Future<void> _uploadSeries() async {
    if (_seriesName == null || _seriesName!.isEmpty) {
      setState(() => _status = 'الرجاء إدخال اسم المسلسل');
      _showSnackBar('الرجاء إدخال اسم المسلسل', isError: true);
      return;
    }
    if (_seriesImagePath == null && _compressedSeriesImagePath == null) {
      setState(() => _status = 'صورة المسلسل مطلوبة');
      _showSnackBar('صورة المسلسل مطلوبة', isError: true);
      return;
    }
    if (_generatedParts.isEmpty) {
      setState(() => _status = 'لا توجد حلقات لرفعها');
      _showSnackBar('لا توجد حلقات لرفعها', isError: true);
      return;
    }

    // بدء الرفع عبر المدير العالمي (اللوحة العامة ستتابع التقدم)
    UploadManager.instance.startUpload(
      UploadRequest(
        seriesName: _seriesName!,
        imagePath: _compressedSeriesImagePath ?? _seriesImagePath,
        episodePaths: List<String>.from(_generatedParts),
      ),
    );
    _showSnackBar('تم بدء رفع المسلسل');
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
        final pickedPath = result.files.single.path!;
        final file = File(pickedPath);
        if (await file.exists()) {
          _originalImageSize = await file.length();
          final compressed = await _compressImage(pickedPath);
          if (compressed != null) {
            _compressedSeriesImagePath = compressed.path;
            _compressedImageSize = await compressed.length();
            _showSnackBar(
              'تم ضغط الصورة (${(_compressedImageSize! / 1024).toStringAsFixed(1)} KB)',
            );
          } else {
            _showSnackBar('تم اختيار الصورة بدون ضغط');
          }
          setState(() {
            _seriesImagePath = pickedPath; // احتفاظ بالمسار الأصلي للعرض
          });
        }
      }
    } catch (e) {
      setState(() => _status = 'خطأ في اختيار الصورة: $e');
      _showSnackBar('خطأ في اختيار الصورة: $e', isError: true);
    }
  }

  Future<File?> _compressImage(String inputPath) async {
    try {
      final ext = p.extension(inputPath).toLowerCase();
      final tempDir = await getTemporaryDirectory();
      final outPath = p.join(
        tempDir.path,
        'series_cover_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final xfile = await FlutterImageCompress.compressAndGetFile(
        inputPath,
        outPath,
        quality: 70,
        format: ext == '.png' ? CompressFormat.png : CompressFormat.jpeg,
        minWidth: 600,
        minHeight: 600,
      );
      if (xfile == null) return null;
      return File(xfile.path);
    } catch (e) {
      if (kDebugMode) print('Compression error: $e');
      return null;
    }
  }

  Future<void> _startProcessing() async {
    // لا نحذف القديم تلقائياً حسب طلبك، فقط نبدأ فوقه. يمكن للمستخدم تنظيفه يدوياً.
    if (_selectedVideoPath == null) {
      setState(() => _status = 'لم يتم اختيار فيديو');
      _showSnackBar('الرجاء اختيار فيديو أولاً', isError: true);
      return;
    }
    setState(() {
      _isProcessing = true;
      _status = 'جاري التحضير...';
      _progress = 0;
      _generatedParts.clear();
    });
    _partsTarget = null;

    Future<void> runProcessing() async {
      final result = _randomMode
          ? await VideoProcessor.instance.processRandom(
              inputPath: _selectedVideoPath!,
              minSeconds: 90,
              maxSeconds: 120,
              onPartComplete: (idx, total) {
                if (!mounted) return;
                setState(() {
                  if (total != null) _partsTarget = total;
                  // idx يبدأ من 1 في المعالج العادي، وفي العشوائي قد يكون 0 فنعالجه
                  final partIndex = idx <= 0 ? 1 : idx;
                  final totalParts =
                      _partsTarget ??
                      total ??
                      (_randomMode
                          ? (partIndex + 2)
                          : partIndex); // تقدير بسيط للعشوائي
                  _status = _randomMode
                      ? 'قص جزء عشوائي رقم $partIndex'
                      : 'قص الجزء $partIndex من $totalParts';
                  if (totalParts > 0) {
                    _progress = partIndex / totalParts;
                    if (_progress > 1) _progress = 1;
                  } else {
                    _progress = 0.05 * partIndex; // تقدير مبسط للعشوائي
                    if (_progress > 0.9) _progress = 0.9;
                  }
                });
              },
            )
          : await VideoProcessor.instance.process(
              inputPath: _selectedVideoPath!,
              segmentSeconds: _selectedDuration,
              onPartComplete: (idx, total) {
                if (!mounted) return;
                setState(() {
                  _partsTarget = total;
                  final partIndex = idx; // هنا يبدأ من 1
                  final totalParts = total ?? partIndex;
                  _status = 'قص الجزء $partIndex من $totalParts';
                  _progress = totalParts > 0 ? partIndex / totalParts : 0;
                });
              },
            );

      if (!mounted) return;
      if (result.success) {
        setState(() {
          _generatedParts.addAll(result.parts);
          _totalParts = result.parts.length;
          _isProcessing = false;
          _progress = 1;
          _status = 'تم الانتهاء! $_totalParts أجزاء جاهزة';
        });
        _showSnackBar('تم القص بنجاح');
      } else {
        setState(() {
          _isProcessing = false;
          _status = 'فشل القص: ${result.error}';
        });
        _showSnackBar(result.error ?? 'فشل غير معروف', isError: true);
      }
    }

    // تنفيذ منفصل لتجنب حجب الواجهة
    Future.microtask(runProcessing);
  }

  Future<int> _cleanCurrentGeneratedParts() async {
    int removed = 0;
    for (final path in List<String>.from(_generatedParts)) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
          removed++;
        }
      } catch (_) {}
    }
    if (removed > 0) {
      setState(() {
        _generatedParts.clear();
        _totalParts = 0;
        _status = 'تم تنظيف الأجزاء المحلية';
      });
    }
    // استدعاء مدير الرفع لتنظيف المسارات المحتفظة داخلياً (اختياري)
    await UploadManager.instance.cleanLocalEpisodes();
    return removed;
  }

  Future<int> _cleanAllPartFilesInDirectory() async {
    int removed = 0;
    try {
      final dir = await VideoProcessor.getOutputDirectory();
      if (await dir.exists()) {
        final files = dir.listSync().whereType<File>().where(
          (f) =>
              f.path.toLowerCase().contains('part_') && f.path.endsWith('.mp4'),
        );
        for (final f in files) {
          try {
            await f.delete();
            removed++;
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (removed > 0) {
      setState(() {
        _generatedParts.clear();
        _totalParts = 0;
        _status = 'تم حذف كل الأجزاء من المجلد';
      });
    }
    await UploadManager.instance.cleanLocalEpisodes();
    return removed;
  }

  void _showDurationDialog() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return AlertDialog(
              backgroundColor: const Color(0xFF222233),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'إعداد مدة الأجزاء',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      value: _randomMode,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: Colors.amber,
                      title: Text(
                        'قص عشوائي (90-120 ثانية)',
                        style: TextStyle(
                          color: _randomMode ? Colors.amber : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _randomMode
                            ? 'سيتم إنشاء أطوال متغيرة لكل جزء'
                            : 'مغلق: اختر مدة ثابتة أدناه',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onChanged: (v) {
                        setState(() => _randomMode = v);
                        setInner(() {});
                      },
                    ),
                    const Divider(color: Colors.white24),
                    ...durationOptions.entries.map((e) {
                      final sel = _selectedDuration == e.value;
                      return ListTile(
                        dense: true,
                        enabled: !_randomMode,
                        title: Text(
                          e.key,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white70,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'مدة: ${e.value ~/ 60} دقيقة',
                          style: const TextStyle(color: Colors.white38),
                        ),
                        trailing: sel
                            ? const Icon(Icons.check, color: Colors.amber)
                            : null,
                        onTap: () {
                          if (_randomMode) return;
                          setState(() => _selectedDuration = e.value);
                          Navigator.pop(context);
                          _dialogOpen = false;
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _dialogOpen = false;
                  },
                  child: const Text(
                    'إغلاق',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    _dialogOpen = false;
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
                  if (_seriesImagePath != null) ...[
                    const SizedBox(height: 12),
                    _buildImagePreview(),
                  ],
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
            IconButton(
              icon: const Icon(Icons.timer_outlined, color: Colors.white),
              tooltip: 'إعداد مدة الأجزاء / عشوائي',
              onPressed: () {
                if (_isProcessing) return;
                _showDurationDialog();
              },
            ),
            GestureDetector(
              onLongPress: _isCleaning
                  ? null
                  : () async {
                      setState(() => _isCleaning = true);
                      final removed = await _cleanAllPartFilesInDirectory();
                      if (!mounted) return;
                      setState(() => _isCleaning = false);
                      _showSnackBar(
                        removed > 0
                            ? 'تم حذف $removed ملف (كامل)'
                            : 'لا توجد ملفات للحذف الكامل',
                      );
                    },
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: 'حذف الأجزاء الحالية (اضغط مطول للحذف الكامل)',
                onPressed: _isCleaning
                    ? null
                    : () async {
                        setState(() => _isCleaning = true);
                        final removed = await _cleanCurrentGeneratedParts();
                        if (!mounted) return;
                        setState(() => _isCleaning = false);
                        _showSnackBar(
                          removed > 0
                              ? 'تم حذف $removed ملف'
                              : 'لا توجد ملفات لحذفها',
                        );
                      },
              ),
            ),
            if (_generatedParts.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.upload, color: Colors.white),
                onPressed: _showSeriesDialog,
                tooltip: 'رفع المسلسل',
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
                  const SizedBox(height: 16),

                  const SizedBox(height: 24),
                  _buildVideoSelectionCard(),
                  const SizedBox(height: 20),

                  const SizedBox(height: 20),
                  _buildSettingsCard(),
                  const SizedBox(height: 20),
                  if (kIsWeb) _buildWebExportPlaceholder(),
                  if (kIsWeb) const SizedBox(height: 20),
                  if (_isProcessing) _buildProcessingSection(),
                  const SizedBox(height: 20),
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
            child: const Text(
              'اختر مدة الأجزاء من الشريط العلوي (الأيقونة بجانب الرفع).',
              style: TextStyle(color: Colors.white70, fontSize: 12),
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
          if (_generatedParts.isNotEmpty) ...[const SizedBox(height: 16)],
        ],
      ),
    );
  }

  // قسم عرض تقدم عملية القص فقط (الرفع يعرض في اللوحة العامة)
  Widget _buildProcessingSection() {
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
                child: const Icon(
                  Icons.content_cut,
                  color: Color(0xFF6C63FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'جاري المعالجة...',
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

  /// Placeholder section for the web build explaining export status.
  Widget _buildWebExportPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF03A9F4).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.web, color: Color(0xFF03A9F4), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'دعم الويب (تنزيل الأجزاء)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'القص المحلي غير متاح حالياً على الويب. سيتم قريباً إضافة إحدى الطريقتين:\n• دمج ffmpeg.wasm للمعالجة داخل المتصفح\n• أو استدعاء API خادم يعيد روابط محتوى جاهزة\n\nبعد تنفيذ إحدى الطريقتين سيظهر زر تنزيل الحلقات مباشرة.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final path = _compressedSeriesImagePath ?? _seriesImagePath;
    if (path == null) return const SizedBox.shrink();
    final originalKb = _originalImageSize != null
        ? (_originalImageSize! / 1024).toStringAsFixed(1)
        : null;
    final compressedKb = _compressedImageSize != null
        ? (_compressedImageSize! / 1024).toStringAsFixed(1)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        if (originalKb != null)
          Text(
            compressedKb != null
                ? 'الحجم: قبل $originalKb KB | بعد $compressedKb KB'
                : 'الحجم: $originalKb KB',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
      ],
    );
  }
}
