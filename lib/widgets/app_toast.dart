import 'package:flutter/material.dart';

/// أنواع التوست
enum ToastType { success, error, info, warning }

/// كلاس توست احترافي بصور/أيقونات + أنيميشن + طابور عرض
class AppToast {
  static OverlayEntry? _currentEntry;
  static bool _showing = false;
  static final List<_ToastRequest> _queue = [];

  static void show(
    BuildContext context,
    String message, {
    String? title,
    ToastType type = ToastType.info,
    String? imageAsset,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    bool dismissible = true,
  }) {
    final overlay = Overlay.of(context);
    _queue.add(
      _ToastRequest(
        context: context,
        message: message,
        title: title,
        type: type,
        imageAsset: imageAsset,
        icon: icon,
        duration: duration,
        dismissible: dismissible,
      ),
    );
    if (!_showing) _displayNext(overlay);
  }

  static void _displayNext(OverlayState overlay) {
    if (_queue.isEmpty) {
      _showing = false;
      return;
    }
    _showing = true;
    final req = _queue.removeAt(0);
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        request: req,
        onClosed: () {
          _currentEntry?.remove();
          _currentEntry = null;
          _displayNext(overlay);
        },
      ),
    );
    overlay.insert(_currentEntry!);
  }
}

class _ToastRequest {
  final BuildContext context;
  final String message;
  final String? title;
  final ToastType type;
  final String? imageAsset;
  final IconData? icon;
  final Duration duration;
  final bool dismissible;
  _ToastRequest({
    required this.context,
    required this.message,
    required this.type,
    this.title,
    this.imageAsset,
    this.icon,
    required this.duration,
    required this.dismissible,
  });
}

class _ToastWidget extends StatefulWidget {
  final _ToastRequest request;
  final VoidCallback onClosed;
  const _ToastWidget({required this.request, required this.onClosed});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _startTimer();
  }

  void _startTimer() async {
    await Future.delayed(widget.request.duration);
    if (mounted) _close();
  }

  Future<void> _close() async {
    await _controller.reverse();
    if (mounted) widget.onClosed();
  }

  (List<Color>, Color) _colors(ToastType type) {
    if (type == ToastType.success) {
      return (
        [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
        const Color(0xFF4CAF50),
      );
    } else if (type == ToastType.error) {
      return (
        [const Color(0xFFE53935), const Color(0xFFB71C1C)],
        const Color(0xFFE53935),
      );
    } else if (type == ToastType.warning) {
      return (
        [const Color(0xFFFFA000), const Color(0xFFF57C00)],
        const Color(0xFFFFA000),
      );
    }
    return (
      [const Color(0xFF6C63FF), const Color(0xFF4845D2)],
      const Color(0xFF6C63FF),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (gradientColors, accent) = _colors(widget.request.type);
    final imageAsset = widget.request.imageAsset ?? 'assets/icons/app_icon.png';
    final showImage =
        widget.request.imageAsset != null || widget.request.icon == null;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 90,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.request.dismissible ? _close : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          imageAsset,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.request.icon, color: Colors.white),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.request.title != null)
                            Text(
                              widget.request.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            widget.request.message,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.request.dismissible)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.9),
                          size: 18,
                        ),
                        onPressed: _close,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
