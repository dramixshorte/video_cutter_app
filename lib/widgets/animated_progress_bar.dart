import 'dart:math' as math;
import 'package:flutter/material.dart';

/// AnimatedProgressBar 2025 style
/// - شريط تقدم متدرج متحرك (Shimmer)
/// - انتقالات سلسة بين قيم progress
/// - وسم (Label) ذكي للحالة (تنزيل / مشاهدة / مكتمل)
/// - دعم نمط نجاح عند 100%
class AnimatedProgressBar extends StatefulWidget {
  final double value; // 0..1
  final bool downloading;
  final bool completed;
  final String semanticLabel; // نص وصفي بالعربية
  final Color downloadStartColor;
  final Color downloadEndColor;
  final Color watchStartColor;
  final Color watchEndColor;
  final Duration animationDuration;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.downloading,
    required this.completed,
    required this.semanticLabel,
    this.downloadStartColor = const Color(0xFF6C63FF),
    this.downloadEndColor = const Color(0xFF8F7BFF),
    this.watchStartColor = const Color(0xFF4CC9F0),
    this.watchEndColor = const Color(0xFF4361EE),
    this.animationDuration = const Duration(milliseconds: 450),
    this.height = 14,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  double _displayValue = 0;
  AnimationController? _valueAnimCtrl;
  Animation<double>? _valueTween;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value.clamp(0.0, 1.0);
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newVal = widget.value.clamp(0.0, 1.0);
    if ((newVal - _displayValue).abs() > 0.001) {
      _valueAnimCtrl?.dispose();
      _valueAnimCtrl = AnimationController(
        vsync: this,
        duration: widget.animationDuration,
      );
      final curve = CurvedAnimation(
        parent: _valueAnimCtrl!,
        curve: Curves.easeOutCubic,
      );
      _valueTween =
          Tween<double>(begin: _displayValue, end: newVal).animate(curve)
            ..addListener(() {
              setState(() => _displayValue = _valueTween!.value);
            });
      _valueAnimCtrl!.forward();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _valueAnimCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDownloading = widget.downloading;
    final isComplete = widget.completed || _displayValue >= 0.999;
    final fraction = _displayValue.clamp(0.0, 1.0);
    final gradient = LinearGradient(
      colors: isDownloading
          ? [widget.downloadStartColor, widget.downloadEndColor]
          : [widget.watchStartColor, widget.watchEndColor],
    );

    return Semantics(
      label: widget.semanticLabel,
      value: '${(fraction * 100).floor()}%',
      child: SizedBox(
        // تمت زيادة الارتفاع الاستيعابي (Previous: +22) لمنع Overflow رأسي بمقدار 1px
        // bar height + (percent bubble visual space + spacing + row height تقديري)
        height: widget.height + 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(widget.height),
              child: LayoutBuilder(
                builder: (context, constr) {
                  final w = constr.maxWidth;
                  return Stack(
                    children: [
                      // background
                      Container(
                        height: widget.height,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                      // fill bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        height: widget.height,
                        width: math.max(0.0, w * fraction),
                        decoration: BoxDecoration(gradient: gradient),
                      ),
                      // shimmer overlay only if active & not complete
                      if (!isComplete && isDownloading)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: SizedBox(
                            width: w * fraction,
                            height: widget.height,
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _shimmerCtrl,
                                builder: (_, __) {
                                  final shimmerPos =
                                      (_shimmerCtrl.value * 2 - 0.5);
                                  return CustomPaint(
                                    size: Size(w * fraction, widget.height),
                                    painter: _ShimmerPainter(
                                      progress: shimmerPos,
                                      color: Colors.white.withOpacity(0.28),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      // success glow
                      if (isComplete)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 600),
                            opacity: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.25),
                                    Colors.transparent,
                                  ],
                                  radius: 1.2,
                                  center: const Alignment(0.1, -0.2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // floating percent bubble
                      Positioned(
                        top: 0,
                        left: math.max(0, w * fraction - 34),
                        child: _PercentBubble(
                          percent: (fraction * 100).floor(),
                          highlight: isComplete,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentBubble extends StatelessWidget {
  final int percent;
  final bool highlight;
  const _PercentBubble({required this.percent, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.greenAccent.withOpacity(0.18)
            : Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? Colors.greenAccent.withOpacity(0.55)
              : Colors.white.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Text(
        '$percent%',
        style: TextStyle(
          color: highlight ? Colors.greenAccent : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress; // -0.5 .. 1.5 تقريباً
  final Color color;
  _ShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final paint = Paint()..style = PaintingStyle.fill;
    // نرسم 3 أشرطة diagonal تمر عبر الشريط
    for (int i = -1; i <= 1; i++) {
      final centerX = (progress + i * 0.6) * width;
      final rect = Rect.fromLTWH(centerX - width * 0.2, 0, width * 0.4, height);
      final grad = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.transparent, color, Colors.transparent],
        stops: const [0, 0.5, 1],
      );
      paint.shader = grad.createShader(rect);
      canvas.save();
      // ميل بسيط لإضفاء عمق
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(-0.35);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
