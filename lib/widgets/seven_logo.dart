import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SevenLogo renders the new app logo (number 7 neon stroke) from SVG.
/// Falls back to a painted shape if SVG fails to load.
class SevenLogo extends StatelessWidget {
  final double size;
  final bool withBackground;
  final bool semantic;

  const SevenLogo({
    super.key,
    this.size = 140,
    this.withBackground = true,
    this.semantic = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget emblem = SvgPicture.asset(
      'assets/icons/app_logo_7.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => _fallback(),
    );

    final w = withBackground
        ? ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B1A26), Color(0xFF111017)],
                ),
              ),
              child: emblem,
            ),
          )
        : emblem;

    if (!semantic) return w;
    return Semantics(label: 'App Logo 7', image: true, child: w);
  }

  Widget _fallback() {
    return CustomPaint(
      size: Size.square(size),
      painter: _SevenFallbackPainter(),
    );
  }
}

class _SevenFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.16
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF3D7F), Color(0xFFFFA14E)],
      ).createShader(Offset.zero & size);

    final subtle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..color = Colors.white.withOpacity(0.15);

    final path = Path(); // left coordinate implicit in path via multipliers
    final top = size.height * 0.25;
    final right = size.width * 0.70;
    final bottom = size.height * 0.78;
    // Outline approximating the SVG shape
    path.moveTo(right, top);
    path.lineTo(size.width * 0.43, top);
    path.lineTo(size.width * 0.38, size.height * 0.47);
    path.lineTo(size.width * 0.60, size.height * 0.47);
    path.lineTo(size.width * 0.40, bottom);
    path.lineTo(size.width * 0.55, bottom);
    path.lineTo(right, size.height * 0.55);
    path.close();

    // Glow effect (simple blurred shadow imitation)
    for (int i = 0; i < 4; i++) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth + i * 6
        ..color = const Color(0xFFFF3D7F).withOpacity(0.05 * (4 - i));
      canvas.drawPath(path, glow);
    }

    canvas.drawPath(path, stroke);
    canvas.drawPath(path, subtle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
