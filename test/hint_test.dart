import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/game/game_engine.dart';
import 'package:pow2/game/hint.dart';

void main() {
  group('hint', () {
    test('applyMove slides and merges without a new tile', () {
      final grid = [
        [2, 2, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ];
      expect(applyMove(grid, Direction.left)![0], [4, 0, 0, 0]);
      expect(applyMove(grid, Direction.right)![0], [0, 0, 0, 4]);
      // The tiles are already on the top row, so up changes nothing.
      expect(applyMove(grid, Direction.up), isNull);
      expect(applyMove(grid, Direction.down)![3], [2, 2, 0, 0]);
    });

    test('a swipe that changes nothing gives null', () {
      final grid = [
        [2, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ];
      expect(applyMove(grid, Direction.left), isNull);
      expect(applyMove(grid, Direction.up), isNull);
    });

    test('suggests a swipe that changes the board', () {
      final grid = [
        [2, 4, 8, 16],
        [0, 0, 2, 4],
        [0, 0, 0, 2],
        [0, 0, 0, 0],
      ];
      final move = suggestMove(grid);
      expect(move, isNotNull);
      expect(applyMove(grid, move!), isNotNull);
    });

    test('no swipe left means no hint', () {
      final grid = [
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 2],
      ];
      expect(suggestMove(grid), isNull);
    });
  });
}
