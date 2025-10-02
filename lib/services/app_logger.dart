import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

/// AppLogger: very lightweight JSON-lines logger with simple rotation.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const _fileName = 'download.log';
  static const _maxBytes = 200 * 1024; // 200KB rotation threshold

  File? _file;
  bool _initializing = false;

  Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    if (_initializing) {
      // Wait briefly if concurrent init
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 30));
        if (_file != null) return _file!;
      }
    }
    _initializing = true;
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${dir.path}/logs');
    if (!logsDir.existsSync()) logsDir.createSync(recursive: true);
    final f = File('${logsDir.path}/$_fileName');
    _file = f;
    _initializing = false;
    return f;
  }

  Future<void> log(String event, {Map<String, dynamic>? data}) async {
    try {
      final f = await _ensureFile();
      if (f.existsSync() && f.lengthSync() > _maxBytes) {
        // simple rotation: delete old
        try {
          f.deleteSync();
        } catch (_) {}
      }
      final record = <String, dynamic>{
        'ts': DateTime.now().toIso8601String(),
        'event': event,
        if (data != null) ...data,
      };
      await f.writeAsString(
        '${jsonEncode(record)}\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // swallow logging errors
    }
  }
}
