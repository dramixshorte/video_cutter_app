import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

/// كائن يحمل رابط موقّت للحلقة
class SignedEpisodeUrl {
  final String url;
  final DateTime expiresAt;
  SignedEpisodeUrl({required this.url, required this.expiresAt});
  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 5)));
}

/// خدمة جلب الروابط الموقعة (stream / download / thumb)
class SignedUrlService {
  SignedUrlService._();
  static final SignedUrlService instance = SignedUrlService._();

  // cache key => SignedEpisodeUrl
  final Map<String, SignedEpisodeUrl> _cache = {};
  final String _baseApi = 'https://dramaxbox.bbs.tr/App/api.php';

  Future<String> getSignedUrl({required int episodeId, required String mode}) async {
    final key = '$episodeId|$mode';
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) return cached.url;

    final uri = Uri.parse('$_baseApi?action=episode_signed_url&episode_id=$episodeId&mode=$mode');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        await AppLogger.instance.log('signed_url_fail', data: {'id': episodeId.toString(), 'mode': mode, 'status': resp.statusCode});
        throw Exception('HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body);
      if (json['status'] != 'success') {
        await AppLogger.instance.log('signed_url_error', data: {'id': episodeId.toString(), 'mode': mode, 'body': resp.body});
        throw Exception('API status not success');
      }
      final url = json['url']?.toString() ?? '';
      final expires = (json['expires'] is int) ? DateTime.fromMillisecondsSinceEpoch(json['expires'] * 1000) : DateTime.now().add(const Duration(minutes: 8));
      if (url.isEmpty) throw Exception('Empty url');
      final signed = SignedEpisodeUrl(url: url, expiresAt: expires);
      _cache[key] = signed;
      await AppLogger.instance.log('signed_url_ok', data: {'id': episodeId.toString(), 'mode': mode, 'exp': signed.expiresAt.toIso8601String()});
      return url;
    } catch (e) {
      await AppLogger.instance.log('signed_url_exception', data: {'id': episodeId.toString(), 'mode': mode, 'error': e.toString()});
      rethrow;
    }
  }
}
