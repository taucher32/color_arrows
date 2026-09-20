import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/difficulty.dart';
import '../core/level.dart';

class LevelRepository {
  /// Baked levels come from assets, later ones are generated.
  Future<Level> load(int n) async {
    if (n > bakedLevels) return generateFor(n);
    final name = 'level_${n.toString().padLeft(3, '0')}.json';
    final raw = await rootBundle.loadString('assets/levels/$name');
    return Level.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
