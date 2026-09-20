import 'package:flutter/material.dart';

import '../theme.dart';

/// Dimmed scrim with a centered card; it also blocks taps on the board.
class EndCard extends StatelessWidget {
  const EndCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim),
                ),
              ],
              const SizedBox(height: 20),
              for (final a in actions) ...[a, const SizedBox(height: 10)],
            ],
          ),
        ),
      ),
    );
  }
}
