import 'package:flutter/material.dart';

/// Professional styled dialogs (confirm / selection / input) unified design.
/// Usage:
///   await ProDialog.confirm(context, title: 'تنظيف', message: 'متأكد؟');
///   final choice = await ProDialog.select(context, title: 'اختر مدة', options: [...]);
class ProDialog {
  // Prevent opening multiple dialogs simultaneously which could lock UI.
  static bool _isShowing = false;

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    Color? color,
    IconData icon = Icons.help_outline,
    bool danger = false,
  }) async {
    if (_isShowing) return false; // ignore re-entrancy
    _isShowing = true;
    final themeColor =
        color ?? (danger ? const Color(0xFFE53935) : const Color(0xFF6C63FF));
    bool result = false;
    try {
      result =
          await showGeneralDialog<bool>(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'dialog',
            barrierColor: Colors.black.withOpacity(0.55),
            transitionDuration: const Duration(milliseconds: 220),
            pageBuilder: (_, __, ___) => const SizedBox.shrink(),
            transitionBuilder: (_, anim, __, ___) {
              // Simpler animation to reduce potential GPU/layout issues.
              return Opacity(
                opacity: anim.value,
                child: Transform.scale(
                  scale: 0.95 + 0.05 * anim.value,
                  child: _BaseDialog(
                    icon: icon,
                    iconColor: themeColor,
                    title: title,
                    message: message,
                    actions: [
                      _DialogButton(
                        text: cancelText,
                        onTap: () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(false),
                        outline: true,
                      ),
                      _DialogButton(
                        text: confirmText,
                        color: danger ? const Color(0xFFE53935) : themeColor,
                        onTap: () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(true),
                      ),
                    ],
                  ),
                ),
              );
            },
          ) ??
          false;
    } catch (_) {
      // Fallback: use standard showDialog if custom general dialog fails.
      result =
          await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (_) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(false),
                  child: Text(cancelText),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(true),
                  child: Text(confirmText),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      _isShowing = false;
    }
    return result;
  }

  static Future<T?> select<T>(
    BuildContext context, {
    required String title,
    required List<ProOption<T>> options,
    String? message,
    IconData icon = Icons.list_alt,
    Color color = const Color(0xFF6C63FF),
  }) async {
    if (_isShowing) return null;
    _isShowing = true;
    T? result;
    try {
      result = await showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.55),
        barrierLabel: 'dialog',
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        transitionBuilder: (_, anim, __, ___) {
          return Opacity(
            opacity: anim.value,
            child: Transform.scale(
              scale: 0.95 + 0.05 * anim.value,
              child: _BaseDialog(
                icon: icon,
                iconColor: color,
                title: title,
                message: message,
                custom: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      children: options
                          .map((o) => _OptionTile<T>(option: o))
                          .toList(),
                    ),
                  ),
                ),
                actions: [
                  _DialogButton(
                    text: 'إغلاق',
                    outline: true,
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      // Fallback simplified dialog
      result = await showDialog<T>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map(
                      (o) => ListTile(
                        title: Text(o.label),
                        subtitle: o.subtitle != null ? Text(o.subtitle!) : null,
                        onTap: () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(o.value),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } finally {
      _isShowing = false;
    }
    return result;
  }
}

class ProOption<T> {
  final String label;
  final T value;
  final String? subtitle;
  final IconData? icon;
  final bool highlight;
  ProOption({
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.highlight = false,
  });
}

class _OptionTile<T> extends StatelessWidget {
  final ProOption<T> option;
  const _OptionTile({required this.option});
  @override
  Widget build(BuildContext context) {
    final color = option.highlight ? const Color(0xFF6C63FF) : Colors.white70;
    return InkWell(
      onTap: () => Navigator.of(context, rootNavigator: true).pop(option.value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              option.highlight
                  ? const Color(0xFF6C63FF).withOpacity(0.18)
                  : Colors.white.withOpacity(0.05),
              option.highlight
                  ? const Color(0xFF4845D2).withOpacity(0.12)
                  : Colors.white.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: option.highlight
                ? const Color(0xFF6C63FF)
                : Colors.white.withOpacity(0.1),
            width: option.highlight ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (option.icon != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.icon,
                  size: 20,
                  color: const Color(0xFF6C63FF),
                ),
              ),
            if (option.icon != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (option.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      option.subtitle!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaseDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final List<Widget> actions;
  final Widget? custom;
  const _BaseDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    required this.actions,
    this.custom,
  });
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 26),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E2E), Color(0xFF2C2B40)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    iconColor.withOpacity(0.18),
                    iconColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
            if (custom != null) ...[const SizedBox(height: 16), custom!],
            const SizedBox(height: 20),
            Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  Expanded(child: actions[i]),
                  if (i != actions.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? color;
  final bool outline;
  const _DialogButton({
    required this.text,
    required this.onTap,
    this.color,
    this.outline = false,
  });
  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFF6C63FF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: outline
              ? null
              : LinearGradient(
                  colors: [bg, bg.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: outline
              ? Border.all(color: Colors.white.withOpacity(0.25))
              : null,
          color: outline ? Colors.white.withOpacity(0.05) : null,
          boxShadow: outline
              ? []
              : [
                  BoxShadow(
                    color: bg.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: outline ? Colors.white70 : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
