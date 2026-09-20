import 'dart:ui';

import 'package:color_arrows/game/track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  // Cells are 10 units wide and there is no margin, so numbers stay readable.
  Track trackOf(int arrowIndex, {bool useSnake = true}) {
    final level = useSnake ? snake() : pair();
    return Track.forArrow(
      level.arrows[arrowIndex],
      width: level.width,
      height: level.height,
      cell: 10,
      pad: 0,
    );
  }

  group('Track', () {
    test('follows the cells of a bent arrow and then runs straight out', () {
      // L: (0,0) -> (0,1) -> (1,1), head right, one cell from the edge.
      final t = trackOf(2);
      expect(t.bodyLength, 20);
      expect(t.exitTravel, 39); // body 20 + 1.5 cells to the edge + 4
      expect(t.length, 39);
      expect(t.pointAt(0), const Offset(5, 5));
      expect(t.pointAt(10), const Offset(5, 15));
      expect(t.pointAt(20), const Offset(15, 15));
      expect(t.pointAt(30), const Offset(25, 15));
      expect(t.directionAt(5), const Offset(0, 1));
      expect(t.directionAt(25), const Offset(1, 0));
    });

    test('window covers only the requested stretch', () {
      final t = trackOf(2);
      expect(t.window(0, 20).getBounds(), const Rect.fromLTRB(5, 5, 15, 15));
      expect(t.window(10, 30).getBounds(), const Rect.fromLTRB(5, 15, 25, 15));
      expect(t.window(30, 30).getBounds(), Rect.zero);
      expect(t.window(-5, 5).getBounds(), const Rect.fromLTRB(5, 5, 5, 10));
    });

    test('a one-cell arrow gets a short tail', () {
      final t = trackOf(0, useSnake: false);
      expect(t.bodyLength, 3);
      expect(t.pointAt(0), const Offset(2, 5));
      expect(t.pointAt(t.bodyLength), const Offset(5, 5));
      expect(t.directionAt(1), const Offset(1, 0));
    });

    test('exit travel grows with the distance to the edge', () {
      // pair(): arrow 0 is at x=0 of 2 columns, arrow 1 at x=1.
      final far = trackOf(0, useSnake: false);
      final near = trackOf(1, useSnake: false);
      expect(far.exitTravel - near.exitTravel, 10);
    });
  });
}
