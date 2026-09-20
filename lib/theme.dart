import 'package:flutter/material.dart';

import 'core/arrow.dart';

abstract final class AppColors {
  static const background = Color(0xFF0E141B);
  static const panel = Color(0xFF18212C);
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
