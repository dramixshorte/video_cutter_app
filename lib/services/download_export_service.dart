import 'dart:io';
import 'package:flutter/services.dart';

/// DownloadExportService
/// ينقل الملف (بعد تنزيله في مساحة التطبيق) إلى مجلد التنزيلات العام
/// داخل مجلد فرعي باسم التطبيق (VideoCutter) مع دعم Android 10+ عبر MediaStore
/// و Android < 10 عبر النسخ المباشر.
class DownloadExportService {
  DownloadExportService._();
  static final DownloadExportService instance = DownloadExportService._();

  static const MethodChannel _channel = MethodChannel(
    'media_store',
  );

  /// يصدر فيديو موجود محلياً إلى Download/VideoCutter.
  /// يعيد: إما content:// URI (Android 10+) أو مسار فعلي (Android 9 وأقل).
  static Future<String> exportToPublicDownloads({
    required String localPath,
    String? fileName,
  }) async {
    if (localPath.isEmpty) throw ArgumentError('localPath is empty');
    if (!File(localPath).existsSync()) {
      throw ArgumentError('File not found at localPath');
    }
    final result = await _channel.invokeMethod<String>('exportToDownloads', {
      'path': localPath,
      'fileName': fileName,
    });
    if (result == null || result.isEmpty) {
      throw Exception('Export failed (empty result)');
    }
    return result;
  }
}
