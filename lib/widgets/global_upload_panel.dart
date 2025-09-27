import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_cutter_app/services/upload_manager.dart';
import 'package:video_cutter_app/widgets/app_toast.dart';

/// Persistent panel that listens to UploadManager and displays progress
/// across the whole app. Put this near the top of widget tree (e.g. in main scaffold Stack).
class GlobalUploadPanel extends StatefulWidget {
  const GlobalUploadPanel({super.key});

  @override
  State<GlobalUploadPanel> createState() => _GlobalUploadPanelState();
}

class _GlobalUploadPanelState extends State<GlobalUploadPanel>
    with SingleTickerProviderStateMixin {
  late StreamSubscription _sub;
  UploadProgressSnapshot _snapshot = const UploadProgressSnapshot(
    status: UploadStatus.idle,
    overallProgress: 0,
    currentEpisodeProgress: 0,
    currentEpisodeNumber: 0,
    totalEpisodes: 0,
    message: 'لا يوجد رفع حالياً',
    isBusy: false,
    canCancel: false,
  );

  bool _visible = false;
  Timer? _autoHideTimer;
  bool _minimized = false; // حالة التصغير
  Offset _dragOffset = Offset.zero; // إزاحة السحب
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _sub = UploadManager.instance.stream.listen((snap) {
      setState(() {
        _snapshot = snap;
        // Show panel when uploading / finished / error until auto-hide logic.
        if (snap.status == UploadStatus.uploadingImage ||
            snap.status == UploadStatus.creatingSeries ||
            snap.status == UploadStatus.preparing ||
            snap.status == UploadStatus.uploadingEpisodes) {
          _visible = true;
          _autoHideTimer?.cancel();
        } else if (snap.status == UploadStatus.completed ||
            snap.status == UploadStatus.error) {
          _visible = true; // keep then schedule hide
          _autoHideTimer?.cancel();
          _autoHideTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _visible = false);
          });
          if (snap.status == UploadStatus.completed) {
            AppToast.show(
              context,
              'انتهى رفع المسلسل بنجاح',
              type: ToastType.success,
            );
          } else if (snap.status == UploadStatus.error) {
            AppToast.show(context, snap.message, type: ToastType.error);
          }
        } else if (snap.status == UploadStatus.canceled) {
          _visible = true; // show cancellation then hide
          _autoHideTimer?.cancel();
          _autoHideTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _visible = false);
          });
          AppToast.show(context, 'تم إلغاء الرفع', type: ToastType.warning);
        }
      });
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // فقاعة صغيرة عند التصغير
    if (_visible && _minimized) {
      return _buildMiniBubble(context);
    }
    if (!_visible) return const SizedBox.shrink();

    final percent = (_snapshot.overallProgress * 100)
        .clamp(0, 100)
        .toStringAsFixed(0);
    final episodePercent = (_snapshot.currentEpisodeProgress * 100)
        .clamp(0, 100)
        .toStringAsFixed(0);

    // Avoid covering the bottom NavigationBar (height ~65) + safe inset.
    final media = MediaQuery.of(context);
    const navBarHeight = 65.0; // matches BottomRoot NavigationBar height
    final bottomSafe = media.padding.bottom;
    final bottomPadding = navBarHeight + bottomSafe + 12; // lift panel up

    final base = Positioned(
      left: 12 + _dragOffset.dx,
      right: 12 - _dragOffset.dx,
      bottom: bottomPadding - _dragOffset.dy,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _visible ? 1 : 0,
        child: _buildCard(percent, episodePercent),
      ),
    );

    return Stack(children: [base]);
  }

  Widget _buildCard(String percent, String episodePercent) {
    final isDone = _snapshot.status == UploadStatus.completed;
    final isError = _snapshot.status == UploadStatus.error;

    Color baseColor;
    if (isDone) {
      baseColor = const Color(0xFF4CAF50);
    } else if (isError) {
      baseColor = const Color(0xFFE53935);
    } else {
      baseColor = const Color(0xFF6C63FF);
    }

    return GestureDetector(
      onPanStart: (_) => setState(() => _dragging = true),
      onPanUpdate: (d) => setState(() {
        _dragOffset += d.delta;
      }),
      onPanEnd: (_) => setState(() => _dragging = false),
      child: Material(
        color: Colors.transparent,
        child: AnimatedScale(
          scale: _dragging ? 0.98 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  baseColor.withOpacity(0.9),
                  baseColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle
                          : isError
                          ? Icons.error_outline
                          : Icons.cloud_upload,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _snapshot.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // تنظيف الدليل عند توفر ملفات محلية
                    if (UploadManager.instance.hasLocalEpisodes)
                      _windowBtn(
                        icon: Icons.cleaning_services,
                        tooltip: 'تنظيف الدليل',
                        onTap: () async {
                          await UploadManager.instance.cleanLocalEpisodes();
                          AppToast.show(
                            context,
                            'تم التنظيف',
                            type: ToastType.success,
                          );
                        },
                      ),
                    if (_snapshot.status == UploadStatus.uploadingEpisodes ||
                        _snapshot.status == UploadStatus.paused)
                      _windowBtn(
                        icon: _snapshot.status == UploadStatus.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                        tooltip: _snapshot.status == UploadStatus.paused
                            ? 'استئناف'
                            : 'إيقاف مؤقت',
                        onTap: () {
                          if (_snapshot.status == UploadStatus.paused) {
                            UploadManager.instance.resumeUpload();
                          } else {
                            UploadManager.instance.pauseUpload();
                          }
                        },
                      ),
                    _windowBtn(
                      icon: _minimized ? Icons.window : Icons.minimize,
                      tooltip: _minimized ? 'استرجاع' : 'تصغير',
                      onTap: () => setState(() => _minimized = true),
                    ),
                    if (_snapshot.canCancel && !isDone && !isError)
                      _windowBtn(
                        icon: Icons.close,
                        tooltip: 'إلغاء الرفع',
                        onTap: () => UploadManager.instance.cancelUpload(),
                      )
                    else
                      _windowBtn(
                        icon: Icons.close_fullscreen,
                        tooltip: 'إخفاء',
                        onTap: () => setState(() => _visible = false),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildProgressBar(
                  _snapshot.overallProgress,
                  percent,
                  'إجمالي الرفع',
                ),
                if (_snapshot.status == UploadStatus.uploadingEpisodes) ...[
                  const SizedBox(height: 8),
                  _buildProgressBar(
                    _snapshot.currentEpisodeProgress,
                    episodePercent,
                    'الحلقة ${_snapshot.currentEpisodeNumber}/${_snapshot.totalEpisodes}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(double value, String percent, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: value.clamp(0, 1),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 50,
              child: Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBubble(BuildContext context) {
    return Positioned(
      bottom: 80 + MediaQuery.of(context).padding.bottom,
      right: 16,
      child: GestureDetector(
        onTap: () => setState(() => _minimized = false),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4845D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.cloud_upload, color: Colors.white, size: 26),
              if (_snapshot.status == UploadStatus.uploadingEpisodes)
                Positioned(
                  bottom: 2,
                  child: Text(
                    '${(_snapshot.overallProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _windowBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
