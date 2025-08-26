import 'dart:math';
import 'package:http/http.dart' as http;

class NetworkSpeedTester {
  static Future<double> testDownloadSpeed() async {
    try {
      // استخدام ملفات اختبار من مواقع موثوقة
      final testUrls = [
        'https://proof.ovh.net/files/10Mb.dat',
        'http://ipv4.download.thinkbroadband.com/10MB.zip',
        'https://speedtest.selectel.ru/10MB',
      ];

      final random = Random();
      final testUrl = testUrls[random.nextInt(testUrls.length)];

      final startTime = DateTime.now();
      final response = await http.get(Uri.parse(testUrl));
      final endTime = DateTime.now();

      if (response.statusCode == 200) {
        final duration = endTime.difference(startTime).inMilliseconds / 1000;
        final fileSize = response.bodyBytes.length / 1048576; // حجم الملف بالميجابايت
        final speed = fileSize / duration; // السرعة بالميجابايت/ثانية
        
        return speed * 8; // التحويل إلى ميجابت/ثانية
      }
    } catch (e) {
      print('Error testing download speed: $e');
    }
    
    return 0;
  }

  static Future<double> testUploadSpeed() async {
    try {
      // إنشاء بيانات عشوائية للرفع (1 ميجابايت)
      final testData = List<int>.generate(1048576, (i) => i % 256);
      
      final startTime = DateTime.now();
      // محاكاة عملية الرفع (في الواقع التطبيق، ستستخدم الخادم الخاص بك)
      await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1500)));
      final endTime = DateTime.now();

      final duration = endTime.difference(startTime).inMilliseconds / 1000;
      final fileSize = testData.length / 1048576; // حجم الملف بالميجابايت
      final speed = fileSize / duration; // السرعة بالميجابايت/ثانية
      
      return speed * 8; // التحويل إلى ميجابت/ثانية
    } catch (e) {
      print('Error testing upload speed: $e');
    }
    
    return 0;
  }

  static double calculateNetworkStrength(double downloadSpeed, double uploadSpeed) {
    // تحويل السرعات إلى قيمة بين 0 و 1
    final downloadStrength = (downloadSpeed / 50).clamp(0, 1); // نفترض أن 50 ميجابت هي السرعة القصوى
    final uploadStrength = (uploadSpeed / 25).clamp(0, 1); // نفترض أن 25 ميجابت هي السرعة القصوى للرفع
    
    // المتوسط المرجح (نعطي وزن أكبر للتحميل)
    return (downloadStrength * 0.7 + uploadStrength * 0.3);
  }
}