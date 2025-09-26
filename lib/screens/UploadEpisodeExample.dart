import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/background_upload_service.dart';

/// مثال على كيفية استخدام خدمة الرفع في الخلفية
class UploadEpisodeExample extends StatefulWidget {
  const UploadEpisodeExample({super.key});

  @override
  State<UploadEpisodeExample> createState() => _UploadEpisodeExampleState();
}

class _UploadEpisodeExampleState extends State<UploadEpisodeExample> {
  double _uploadProgress = 0.0;
  String _uploadStatus = 'جاهز للرفع';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _setupServiceListener();
  }

  /// الاستماع لتحديثات الخدمة
  void _setupServiceListener() {
    final service = FlutterBackgroundService();

    service.on('upload_progress').listen((event) {
      if (mounted) {
        setState(() {
          _uploadProgress = (event!['progress'] as int).toDouble();
          _uploadStatus = 'جاري الرفع... ${event['progress']}%';
        });
      }
    });

    service.on('upload_success').listen((event) {
      if (mounted) {
        setState(() {
          _uploadProgress = 100.0;
          _uploadStatus = 'تم الرفع بنجاح!';
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع الحلقة بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    service.on('upload_error').listen((event) {
      if (mounted) {
        setState(() {
          _uploadStatus = 'خطأ في الرفع: ${event!['error']}';
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الرفع: ${event!['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// بدء رفع حلقة جديدة
  Future<void> _startUpload() async {
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadStatus = 'بدء الرفع...';
      });

      // مثال على بيانات الحلقة
      await BackgroundUploadService.startUpload(
        filePath: '/path/to/your/video/file.mp4', // مسار الملف الفعلي
        uploadUrl: 'https://dramaxbox.bbs.tr/App/api.php?action=upload_episode',
        fileName: 'episode_01.mp4',
        additionalData: {
          'action': 'upload_episode',
          'series_id': '123',
          'episode_number': '1',
          'season_number': '1',
          'episode_title': 'الحلقة الأولى',
        },
      );
    } catch (e) {
      setState(() {
        _uploadStatus = 'خطأ: $e';
        _isUploading = false;
      });
    }
  }

  /// إيقاف الرفع
  Future<void> _stopUpload() async {
    await BackgroundUploadService.stopUpload();
    setState(() {
      _isUploading = false;
      _uploadStatus = 'تم إيقاف الرفع';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('رفع الحلقات في الخلفية'),
        backgroundColor: const Color(0xFF2D2D44),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة معلومات الرفع
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF4845D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _uploadStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _uploadProgress / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_uploadProgress.toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // معلومات العمل في الخلفية
            Container(
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
                      Icon(Icons.info_outline, color: Colors.blue[300]),
                      const SizedBox(width: 12),
                      const Text(
                        'مزايا العمل في الخلفية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem('✓ الرفع يستمر حتى لو أغلقت التطبيق'),
                  _buildFeatureItem('✓ منع النوم أثناء الرفع'),
                  _buildFeatureItem('✓ إشعارات تفصيلية بالتقدم'),
                  _buildFeatureItem('✓ استكمال الرفع بعد انقطاع الشبكة'),
                ],
              ),
            ),

            const Spacer(),

            // أزرار التحكم
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _startUpload,
                    icon: const Icon(Icons.upload),
                    label: const Text('بدء الرفع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? _stopUpload : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('إيقاف الرفع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
      ),
    );
  }
}
