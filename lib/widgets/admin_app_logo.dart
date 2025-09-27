import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Admin application logo widget.
/// Shows the SVG badge (shield + play + gear). Optional label text.
class AdminAppLogo extends StatelessWidget {
  final double size; // width & height of square area for emblem
  final bool showText;
  final String text;
  final TextStyle? textStyle;
  final double spacing;
  final bool emblemOnly; // if true uses admin_emblem.svg (no ADMIN text baked)

  const AdminAppLogo({
    super.key,
    this.size = 120,
    this.showText = false,
    this.text = 'ADMIN',
    this.textStyle,
    this.spacing = 12,
    this.emblemOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final asset = emblemOnly
        ? 'assets/icons/admin_emblem.svg'
        : 'assets/icons/admin_logo.svg';
    final logo = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3A36E8)],
          ),
        ),
        child: Icon(
          Icons.admin_panel_settings,
          color: Colors.white70,
          size: size * 0.55,
        ),
      ),
    );

    if (!showText) return logo;

    final style =
        textStyle ??
        TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          foreground: Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF3D7F)],
            ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        SizedBox(height: spacing),
        Text(text, style: style),
      ],
    );
  }
}
