import 'dart:math';

import 'package:flutter/material.dart';

import 'core/arrow.dart';

abstract final class AppColors {
  static const background = Color(0xFF0E141B);
  static const panel = Color(0xFF18212C);
  static const cell = Color(0xFF243040);
  static const text = Color(0xFFE8EEF5);
  static const textDim = Color(0xFF8A99AB);

  static const _arrow = {
    ArrowColor.coral: Color(0xFFFF6B6B),
    ArrowColor.amber: Color(0xFFFFB84D),
    ArrowColor.mint: Color(0xFF4ADE9A),
    ArrowColor.sky: Color(0xFF4DA8FF),
    ArrowColor.violet: Color(0xFFA78BFA),
  };

  static Color arrow(ArrowColor c) => _arrow[c]!;
}

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.text,
    surface: AppColors.panel,
  ),
  textTheme: ThemeData.dark().textTheme.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  ),
);

/// Small shape that tells the colors apart without relying on hue alone:
/// circle, square, triangle, plus, star.
void paintMark(Canvas canvas, ArrowColor c, Offset o, double r, Paint paint) {
  switch (c) {
    case ArrowColor.coral:
      canvas.drawCircle(o, r, paint);
    case ArrowColor.amber:
      canvas.drawRect(
        Rect.fromCenter(center: o, width: 1.7 * r, height: 1.7 * r),
        paint,
      );
    case ArrowColor.mint:
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - r)
          ..lineTo(o.dx + r, o.dy + r * 0.8)
          ..lineTo(o.dx - r, o.dy + r * 0.8)
          ..close(),
        paint,
      );
    case ArrowColor.sky:
      final t = r * 0.42;
      canvas
        ..drawRect(
          Rect.fromCenter(center: o, width: 2 * r, height: 2 * t),
          paint,
        )
        ..drawRect(
          Rect.fromCenter(center: o, width: 2 * t, height: 2 * r),
          paint,
        );
    case ArrowColor.violet:
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final radius = i.isEven ? r : r * 0.45;
        final a = -pi / 2 + i * pi / 5;
        final p = Offset(o.dx + radius * cos(a), o.dy + radius * sin(a));
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(star..close(), paint);
  }
}
