import 'package:flutter/material.dart';

/// Lets the player pinch-zoom and pan the board. Taps are reported in the
/// child's own coordinates (before zoom), which is what the game widget
/// expects.
class ZoomableBoard extends StatefulWidget {
  const ZoomableBoard({
    super.key,
    required this.child,
    required this.onTap,
    this.maxScale = 8,
    this.initialScale = 1,
  });

  final Widget child;
  final void Function(Offset position) onTap;
  final double maxScale;

  /// Zoom applied once, about the middle, when the board first appears
  /// (1 = whole board).
  final double initialScale;

  @override
  State<ZoomableBoard> createState() => _ZoomableBoardState();
}

class _ZoomableBoardState extends State<ZoomableBoard> {
  final _controller = TransformationController();
  bool _applied = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_applied) {
          _applied = true;
          final k = widget.initialScale.clamp(1.0, widget.maxScale);
          if (k > 1) {
            final c = constraints.biggest.center(Offset.zero);
            _controller.value = Matrix4.diagonal3Values(k, k, 1)
              ..setTranslationRaw(c.dx * (1 - k), c.dy * (1 - k), 0);
          }
        }
        return InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: widget.maxScale,
          child: GestureDetector(
            onTapUp: (d) => widget.onTap(d.localPosition),
            child: widget.child,
          ),
        );
      },
    );
  }
}
