import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// StoragePermissionHelper
/// يتعامل مع الفروقات بين الإصدارات لطلب الأذونات اللازمة قبل التصدير إلى التنزيلات.
class StoragePermissionHelper {
  static Future<bool> ensureExportPermissions() async {
    if (!Platform.isAndroid) return true; // iOS غير مطبق هنا

    // Android 13+ (API 33): نحتاج READ_MEDIA_VIDEO (أحياناً READ_MEDIA_IMAGES لو حفظنا صوراً)
    // Android <= 32: نطلب إذن التخزين التقليدي (READ/WRITE)
    final sdkInt = await _sdkInt();

    if (sdkInt >= 33) {
      final statusVideo = await Permission.videos.request();
      if (statusVideo.isGranted) return true;
      return false;
    } else {
      // Legacy external storage flow
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  static Future<int> _sdkInt() async {
    // نحاول قراءة من File system property (حل سريع)
    try {
      final ver = Platform.version; // مثال: "Android 14 (API 34)"
      final apiPart = RegExp(r'API (\d+)').firstMatch(ver)?.group(1);
      if (apiPart != null) return int.parse(apiPart);
    } catch (_) {}
    return 33; // افتراضي محافظ
  }
}
