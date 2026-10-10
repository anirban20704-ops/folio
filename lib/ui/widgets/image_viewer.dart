import 'dart:io';
import 'package:flutter/material.dart';

/// Full-screen pop-up image viewer.
///
/// Swipe left/right to move between images without closing the viewer,
/// pinch or double-tap to zoom, tap the X (or press Back) to close.
Future<void> showImageViewer(
  BuildContext context, {
  required List<String> paths,
  int initialIndex = 0,
  List<String>? labels,
}) {
  if (paths.isEmpty) return Future.value();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close image',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => _ImageViewer(
      paths: paths,
      initialIndex: initialIndex.clamp(0, paths.length - 1).toInt(),
      labels: labels,
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class _ImageViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final List<String>? labels;
  const _ImageViewer(
      {required this.paths, required this.initialIndex, this.labels});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _pc =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.paths.length;
    final label = widget.labels != null && _index < widget.labels!.length
        ? widget.labels![_index]
        : null;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: total,
            // Don't swipe pages while the current image is zoomed in
            // (the swipe pans the picture instead).
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() {
              _index = i;
              _zoomed = false;
            }),
            itemBuilder: (_, i) => _ZoomPage(
              key: ValueKey(widget.paths[i]),
              path: widget.paths[i],
              onZoomChanged: (z) {
                if (z != _zoomed && i == _index) setState(() => _zoomed = z);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      label == null
                          ? '${_index + 1} / $total'
                          : '$label  ·  ${_index + 1} / $total',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomPage extends StatefulWidget {
  final String path;
  final ValueChanged<bool> onZoomChanged;
  const _ZoomPage({super.key, required this.path, required this.onZoomChanged});

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final TransformationController _tc = TransformationController();
  Offset _tapAt = Offset.zero;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomedIn = _tc.value.getMaxScaleOnAxis() > 1.05;
    if (zoomedIn) {
      _tc.value = Matrix4.identity();
    } else {
      const s = 2.5;
      // Column-major: scale s about the tapped point.
      _tc.value = Matrix4(
        s, 0, 0, 0, //
        0, s, 0, 0, //
        0, 0, 1, 0, //
        -_tapAt.dx * (s - 1), -_tapAt.dy * (s - 1), 0, 1,
      );
    }
    widget.onZoomChanged(!zoomedIn);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd: (_) =>
            widget.onZoomChanged(_tc.value.getMaxScaleOnAxis() > 1.05),
        child: Center(
          child: Image.file(
            File(widget.path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64),
          ),
        ),
      ),
    );
  }
}
