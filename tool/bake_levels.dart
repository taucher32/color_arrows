// Writes assets/levels/level_001.json .. level_030.json from the difficulty
// curve. Run from the project root: dart run tool/bake_levels.dart
// The files are plain JSON, so any level can be edited by hand afterwards
// (test/services/level_repository_test.dart re-checks them).
import 'dart:convert';
import 'dart:io';

import 'package:color_arrows/core/difficulty.dart';

void main() {
  final dir = Directory('assets/levels')..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (var n = 1; n <= bakedLevels; n++) {
    final name = 'level_${n.toString().padLeft(3, '0')}.json';
    File('${dir.path}/$name')
        .writeAsStringSync('${encoder.convert(generateFor(n).toJson())}\n');
  }
  stdout.writeln('wrote $bakedLevels levels to ${dir.path}');
}
