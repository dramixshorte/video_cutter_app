import 'package:flutter/material.dart';
import 'dart:math';
// كلاس رئيسي للساعات
class Speedometers extends StatelessWidget {
  final double downloadSpeed;
  final double uploadSpeed;
  final double networkStrength;
  final bool isTesting;

  const Speedometers({
    super.key,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.networkStrength,
    required this.isTesting,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سرعة الإنترنت',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ساعة سرعة التحميل
                DownloadSpeedometer(
                  speed: downloadSpeed,
                  isTesting: isTesting,
                ),
                
                // ساعة سرعة الرفع
                UploadSpeedometer(
                  speed: uploadSpeed,
                  isTesting: isTesting,
                ),
                
                // ساعة قوة الشبكة
                NetworkStrengthMeter(
                  strength: networkStrength,
                  isTesting: isTesting,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ساعة سرعة التحميل
class DownloadSpeedometer extends StatelessWidget {
  final double speed;
  final bool isTesting;

  const DownloadSpeedometer({
    super.key,
    required this.speed,
    required this.isTesting,
  });

  @override
  Widget build(BuildContext context) {
    return _SpeedometerBase(
      title: 'التحميل',
      value: speed,
      isTesting: isTesting,
      color: Colors.green,
      icon: Icons.download,
      unit: 'Mbps',
      maxValue: 100,
    );
  }
}

// ساعة سرعة الرفع
class UploadSpeedometer extends StatelessWidget {
  final double speed;
  final bool isTesting;

  const UploadSpeedometer({
    super.key,
    required this.speed,
    required this.isTesting,
  });

  @override
  Widget build(BuildContext context) {
    return _SpeedometerBase(
      title: 'الرفع',
      value: speed,
      isTesting: isTesting,
      color: Colors.blue,
      icon: Icons.upload,
      unit: 'Mbps',
      maxValue: 50,
    );
  }
}

// ساعة قوة الشبكة
class NetworkStrengthMeter extends StatelessWidget {
  final double strength; // قيمة من 0 إلى 1
  final bool isTesting;

  const NetworkStrengthMeter({
    super.key,
    required this.strength,
    required this.isTesting,
  });

  @override
  Widget build(BuildContext context) {
    return _SpeedometerBase(
      title: 'قوة الشبكة',
      value: strength * 100, // تحويل إلى نسبة مئوية
      isTesting: isTesting,
      color: _getNetworkStrengthColor(strength),
      icon: Icons.network_check,
      unit: '%',
      maxValue: 100,
    );
  }

  Color _getNetworkStrengthColor(double strength) {
    if (strength < 0.3) return Colors.red;
    if (strength < 0.6) return Colors.orange;
    if (strength < 0.8) return Colors.yellow;
    return Colors.green;
  }
}

// الكلاس الأساسي لبناء الساعات
class _SpeedometerBase extends StatelessWidget {
  final String title;
  final double value;
  final bool isTesting;
  final Color color;
  final IconData icon;
  final String unit;
  final double maxValue;

  const _SpeedometerBase({
    Key? key,
    required this.title,
    required this.value,
    required this.isTesting,
    required this.color,
    required this.icon,
    required this.unit,
    required this.maxValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value.clamp(0, maxValue) / maxValue;
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // خلفية الساعة
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _SpeedometerPainter(
                  progress: normalizedValue,
                  color: color,
                  isTesting: isTesting,
                ),
              ),
            ),
            
            // المحتوى المركزي
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(
                  isTesting ? '...' : value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}

// رسام الساعة
class _SpeedometerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isTesting;

  _SpeedometerPainter({
    required this.progress,
    required this.color,
    required this.isTesting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 6.0;

    // رسم الخلفية
    final backgroundPaint = Paint()
      ..color = const Color(0xFF444444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -pi,
      pi,
      false,
      backgroundPaint,
    );

    // رسم التقدم
    if (!isTesting) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -pi,
        pi * progress,
        false,
        progressPaint,
      );
    } else {
      // رسم مؤشر التحميل أثناء الاختبار
      final loadingPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // رسم مؤشر دوار
      final currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
      final loadingProgress = (currentTime % 1.0);
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -pi + (2 * pi * loadingProgress),
        pi * 0.5,
        false,
        loadingPaint,
      );
    }

    // رسم العلامات
    final markerPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final angle = -pi + (pi / 4 * i);
      final start = Offset(
        center.dx + (radius - strokeWidth - 5) * cos(angle),
        center.dy + (radius - strokeWidth - 5) * sin(angle),
      );
      final end = Offset(
        center.dx + (radius - strokeWidth - 15) * cos(angle),
        center.dy + (radius - strokeWidth - 15) * sin(angle),
      );
      
      canvas.drawLine(start, end, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}