import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Helper responsible for exporting generated video parts on the Web.
/// Currently this is only a placeholder because local slicing is not yet
/// implemented for the web build. Once parts are produced in-memory as
/// bytes (via ffmpeg.wasm or a backend API) we will:
/// 1. Turn each part's bytes into a `Blob`.
/// 2. Create an object URL with `Url.createObjectUrlFromBlob`.
/// 3. Trigger a download by injecting an invisible anchor `<a download>`.
/// 4. Revoke the object URL after a short delay.
///
/// For now we simply show an informational dialog to the user.
class WebExportHelper {
  WebExportHelper._();

  static Future<void> exportParts(
    BuildContext context,
    List<String> partPaths,
  ) async {
    if (!kIsWeb) return; // Only relevant to web
    // Placeholder: show info dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'تنزيل الحلقات (قريباً)',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'ميزة تنزيل الأجزاء داخل المتصفح غير متاحة حالياً. سيتم دعم التصدير باستخدام ffmpeg.wasm أو عبر واجهة خادم لاحقاً.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
