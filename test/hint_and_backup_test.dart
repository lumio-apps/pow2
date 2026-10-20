import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/app_controller.dart';
import 'package:pow2/game/game_config.dart';
import 'package:pow2/game/game_engine.dart';
import 'package:pow2/game/game_storage.dart';
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

  group('backup', () {
    test('a backup can be restored on another phone', () {
      final a = AppController(GameStorage.inMemory());
      a.submitScore(GameConfig.standard, 900);
      a.submitScore(const GameConfig(GameMode.timed, 5), 300);
      a.recordMove(highestTile: 256);
      a.recordGameFinished();
      a.setTheme(2);
      a.markDailyPlayed(20261020);
      a.checkAchievements(config: GameConfig.standard, score: 900, tile: 256);

      final b = AppController(GameStorage.inMemory());
      expect(b.importBackup(a.exportBackup()), isTrue);
      expect(b.bestFor(GameConfig.standard), 900);
      expect(b.bestFor(const GameConfig(GameMode.timed, 5)), 300);
      expect(b.stats.highestTile, 256);
      expect(b.stats.gamesPlayed, 1);
      expect(b.themeIndex, 2);
      expect(b.unlockedIds, contains('tile128'));
      expect(b.dailyDaysPlayed, 1);
    });

    test('restoring never lowers what is already there', () {
      final old = AppController(GameStorage.inMemory());
      old.submitScore(GameConfig.standard, 100);
      final backup = old.exportBackup();

      final current = AppController(GameStorage.inMemory());
      current.submitScore(GameConfig.standard, 5000);
      expect(current.importBackup(backup), isTrue);
      expect(current.bestFor(GameConfig.standard), 5000);
    });

    test('bad text is rejected and changes nothing', () {
      final c = AppController(GameStorage.inMemory());
      c.submitScore(GameConfig.standard, 40);
      expect(c.importBackup('hello'), isFalse);
      expect(c.importBackup('POW2-BACKUP-1:@@@'), isFalse);
      expect(c.bestFor(GameConfig.standard), 40);
    });

    test('text with line breaks still works', () {
      final a = AppController(GameStorage.inMemory());
      a.submitScore(GameConfig.standard, 70);
      final text = a.exportBackup();
      final split = '${text.substring(0, 20)}\n ${text.substring(20)}';
      final b = AppController(GameStorage.inMemory());
      expect(b.importBackup(split), isTrue);
      expect(b.bestFor(GameConfig.standard), 70);
    });
  });
}
