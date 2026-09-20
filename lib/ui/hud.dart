import 'dart:math';

import 'package:flutter/material.dart';

import '../core/arrow.dart';
import '../core/session.dart';
import '../theme.dart';

/// Level number, lives and the color goal above the board.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.levelNumber, required this.session});

  final int levelNumber;
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Bölüm $levelNumber',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            for (var i = 0; i < max(startLives, session.lives); i++)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  i < session.lives ? Icons.circle : Icons.circle_outlined,
                  size: 16,
                  color: AppColors.arrow(ArrowColor.coral),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: session.level.isSequenced ? _steps() : _colors(),
        ),
      ],
    );
  }

  List<Widget> _colors() {
    final left = session.remainingByColor;
    final colors = {for (final a in session.level.arrows) a.color};
    return [
      for (final c in ArrowColor.values.where(colors.contains))
        ColorChip(color: c, label: '${left[c] ?? 0}', state: ChipState.pending),
    ];
  }

  List<Widget> _steps() {
    final steps = session.level.steps!;
    final removed = session.removedCount;
    final active = session.activeStep;
    var end = 0;
    return [
      for (final s in steps)
        () {
          final start = end;
          end += s.count;
          if (removed >= end) {
            return ColorChip(color: s.color, label: '✓', state: ChipState.done);
          }
          if (removed >= start && active != null) {
            return ColorChip(
              color: s.color,
              label: '${active.left}',
              state: ChipState.active,
            );
          }
          return ColorChip(
            color: s.color,
            label: '${s.count}',
            state: ChipState.pending,
          );
        }(),
    ];
  }
}

enum ChipState { done, active, pending }

class ColorChip extends StatelessWidget {
  const ColorChip({
    super.key,
    required this.color,
    required this.label,
    required this.state,
  });

  final ArrowColor color;
  final String label;
  final ChipState state;

  @override
  Widget build(BuildContext context) {
    final base = AppColors.arrow(color);
    final opacity = switch (state) {
      ChipState.done => 0.3,
      ChipState.active => 1.0,
      ChipState.pending => 0.75,
    };
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: state == ChipState.active ? base : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(size: const Size(14, 14), painter: _MarkPainter(color)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final ArrowColor color;

  @override
  void paint(Canvas canvas, Size size) => paintMark(
    canvas,
    color,
    size.center(Offset.zero),
    size.width / 2,
    Paint()..color = AppColors.arrow(color),
  );

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
