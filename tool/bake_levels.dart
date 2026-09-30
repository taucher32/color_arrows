// Writes assets/levels/level_001.json .. level_030.json from the difficulty
// curve. Run from the project root: dart run tool/bake_levels.dart
// One arrow per line, so a level is easy to read and edit by hand
// (test/services/level_repository_test.dart re-checks the files).
import 'dart:convert';
import 'dart:io';

import 'package:renok/core/difficulty.dart';
import 'package:renok/core/level.dart';

String encode(Level level) {
  final json = level.toJson();
  final arrows = (json['arrows'] as List).map((a) => '  ${jsonEncode(a)}');
  final steps = json['steps'];
  return '{"w":${level.width},"h":${level.height},\n'
      '"arrows":[\n${arrows.join(',\n')}\n]'
      '${steps == null ? '' : ',\n"steps":${jsonEncode(steps)}'}}\n';
}

void main() {
  final dir = Directory('assets/levels')..createSync(recursive: true);
  for (var n = 1; n <= bakedLevels; n++) {
    final name = 'level_${n.toString().padLeft(3, '0')}.json';
    File('${dir.path}/$name').writeAsStringSync(encode(generateFor(n)));
  }
  stdout.writeln('wrote $bakedLevels levels to ${dir.path}');
}
