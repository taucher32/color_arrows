import 'package:flutter/material.dart';

import '../theme.dart';

/// Lets the player pinch-zoom and pan the board, and offers +, - and fit
/// buttons for when pinching is awkward. Taps are reported in the child's own
/// coordinates (before zoom), which is what the game widget expects.
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

  /// Zoom applied once when the board first appears (1 = whole board).
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

  /// Scales about the middle of the view; 1x is exactly the untouched view.
  void _zoom(double factor, Size size) {
    final current = _controller.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, widget.maxScale);
    if (target <= 1.0) {
      _controller.value = Matrix4.identity();
      return;
    }
    final k = target / current;
    final c = size.center(Offset.zero);
    final m =
        Matrix4.translationValues(c.dx, c.dy, 0) *
        Matrix4.diagonal3Values(k, k, 1) *
        Matrix4.translationValues(-c.dx, -c.dy, 0) *
        _controller.value;
    // Keep the board covering the view, as the pan gesture does.
    final tx = m.storage[12].clamp(size.width * (1 - target), 0.0);
    final ty = m.storage[13].clamp(size.height * (1 - target), 0.0);
    _controller.value = Matrix4.diagonal3Values(target, target, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!_applied) {
          _applied = true;
          if (widget.initialScale > 1) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _zoom(widget.initialScale, size),
            );
          }
        }
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: widget.maxScale,
                child: GestureDetector(
                  onTapUp: (d) => widget.onTap(d.localPosition),
                  child: widget.child,
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ZoomButton(
                    icon: Icons.add,
                    tooltip: 'Yakınlaştır',
                    onPressed: () => _zoom(1.6, size),
                  ),
                  _ZoomButton(
                    icon: Icons.remove,
                    tooltip: 'Uzaklaştır',
                    onPressed: () => _zoom(1 / 1.6, size),
                  ),
                  _ZoomButton(
                    icon: Icons.fit_screen,
                    tooltip: 'Sığdır',
                    onPressed: () => _controller.value = Matrix4.identity(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.panel.withValues(alpha: 0.92),
          foregroundColor: AppColors.text,
          minimumSize: const Size(40, 40),
        ),
      ),
    );
  }
}
