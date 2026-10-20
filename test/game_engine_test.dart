import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/game/game_engine.dart';

GameEngine engineWith(List<List<int>> values) {
  final engine = GameEngine(random: Random(1));
  engine.loadValues(values);
  return engine;
}

const List<int> emptyRow = [0, 0, 0, 0];

void main() {
  group('moves', () {
    test('merges each pair only once per move', () {
      final engine = engineWith([
        [2, 2, 2, 2],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      final result = engine.move(Direction.left, spawnTile: false);
      expect(result.moved, isTrue);
      expect(result.gained, 8);
      expect(engine.grid[0], [4, 4, 0, 0]);
      expect(engine.score, 8);
    });

    test('does not chain merges inside one move', () {
      final engine = engineWith([
        [4, 2, 2, 0],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      final result = engine.move(Direction.left, spawnTile: false);
      expect(result.gained, 4);
      expect(engine.grid[0], [4, 4, 0, 0]);
    });

    test('moves and merges to the right', () {
      final engine = engineWith([
        [0, 2, 0, 2],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      engine.move(Direction.right, spawnTile: false);
      expect(engine.grid[0], [0, 0, 0, 4]);
    });

    test('moves and merges upwards', () {
      final engine = engineWith([
        emptyRow,
        emptyRow,
        [2, 0, 0, 0],
        [2, 0, 0, 0],
      ]);
      engine.move(Direction.up, spawnTile: false);
      expect(engine.grid.map((row) => row[0]).toList(), [4, 0, 0, 0]);
    });

    test('moves and merges downwards', () {
      final engine = engineWith([
        [2, 0, 0, 0],
        [2, 0, 0, 0],
        emptyRow,
        emptyRow,
      ]);
      engine.move(Direction.down, spawnTile: false);
      expect(engine.grid.map((row) => row[0]).toList(), [0, 0, 0, 4]);
    });

    test('a move that changes nothing is ignored', () {
      final engine = engineWith([
        [2, 4, 8, 16],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      final result = engine.move(Direction.left);
      expect(result.moved, isFalse);
      expect(engine.tiles.length, 4);
      expect(engine.canUndo, isFalse);
    });

    test('spawns one new tile after a move', () {
      final engine = engineWith([
        [2, 0, 0, 0],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      engine.move(Direction.right);
      expect(engine.tiles.length, 2);
      expect(engine.tiles.where((t) => t.isNew).length, 1);
    });
  });

  group('undo', () {
    test('restores the board and score of the last move', () {
      final engine = engineWith([
        [2, 2, 0, 0],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      engine.move(Direction.left);
      expect(engine.canUndo, isTrue);
      expect(engine.undo(), isTrue);
      expect(engine.grid[0], [2, 2, 0, 0]);
      expect(engine.tiles.length, 2);
      expect(engine.score, 0);
      expect(engine.canUndo, isFalse);
    });
  });

  group('game over', () {
    test('full board without equal neighbours is over', () {
      final engine = engineWith([
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 2],
      ]);
      expect(engine.isGameOver, isTrue);
    });

    test('full board with a possible merge is not over', () {
      final engine = engineWith([
        [2, 2, 4, 8],
        [4, 8, 2, 4],
        [2, 4, 8, 2],
        [4, 2, 4, 8],
      ]);
      expect(engine.isGameOver, isFalse);
    });

    test('board with an empty cell is not over', () {
      final engine = engineWith([
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 0],
      ]);
      expect(engine.isGameOver, isFalse);
    });
  });

  group('milestones', () {
    test('are reported once, then not again', () {
      final engine = engineWith([
        [1024, 2, 0, 0],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      expect(engine.takeMilestone(), 1024);
      expect(engine.takeMilestone(), isNull);
    });

    test('small tiles give no milestone', () {
      final engine = engineWith([
        [128, 2, 0, 0],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      expect(engine.takeMilestone(), isNull);
    });
  });

  group('saving', () {
    test('a saved game can be restored', () {
      final engine = engineWith([
        [2, 4, 0, 0],
        [0, 8, 0, 0],
        emptyRow,
        emptyRow,
      ]);
      engine.score = 40;
      final saved = jsonDecode(jsonEncode(engine.toJson())) as Map<String, dynamic>;

      final restored = GameEngine(random: Random(2));
      expect(restored.restore(saved), isTrue);
      expect(restored.grid, engine.grid);
      expect(restored.score, 40);
    });

    test('invalid data is rejected', () {
      final engine = GameEngine(random: Random(3));
      expect(engine.restore({'tiles': 'oops'}), isFalse);
      expect(engine.restore({'tiles': <dynamic>[]}), isFalse);
    });
  });

  group('undo steps', () {
    test('keeps up to 3 steps', () {
      final engine = engineWith([
        [2, 0, 0, 0],
        emptyRow,
        emptyRow,
        emptyRow,
      ]);
      engine.move(Direction.right, spawnTile: false);
      engine.move(Direction.left, spawnTile: false);
      engine.move(Direction.right, spawnTile: false);
      engine.move(Direction.left, spawnTile: false);
      expect(engine.undoDepth, 3);
      expect(engine.undo(), isTrue);
      expect(engine.undo(), isTrue);
      expect(engine.undo(), isTrue);
      expect(engine.undo(), isFalse);
      expect(engine.grid[0], [0, 0, 0, 2]);
    });
  });

  group('board sizes', () {
    test('a 3x3 board starts with 2 tiles', () {
      final engine = GameEngine(size: 3, random: Random(4))..reset();
      expect(engine.grid.length, 3);
      expect(engine.tiles.length, 2);
    });

    test('a full 3x3 board with no merges is game over', () {
      final engine = GameEngine(size: 3, random: Random(5));
      engine.loadValues([
        [2, 4, 2],
        [4, 2, 4],
        [2, 4, 2],
      ]);
      expect(engine.isGameOver, isTrue);
    });

    test('a saved game of another size is rejected', () {
      final six = GameEngine(size: 6, random: Random(6))..reset();
      final saved = jsonDecode(jsonEncode(six.toJson())) as Map<String, dynamic>;
      expect(GameEngine(random: Random(7)).restore(saved), isFalse);
      expect(GameEngine(size: 6, random: Random(8)).restore(saved), isTrue);
    });
  });

  group('zen', () {
    test('clearing the smallest tiles frees the board', () {
      final engine = engineWith([
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 8, 4, 2],
      ]);
      expect(engine.isGameOver, isTrue);
      expect(engine.clearSmallest(), 7);
      expect(engine.isGameOver, isFalse);
    });
  });
}
