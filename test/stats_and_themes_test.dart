import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/app_controller.dart';
import 'package:pow2/game/game_config.dart';
import 'package:pow2/game/game_stats.dart';
import 'package:pow2/game/game_storage.dart';
import 'package:pow2/theme.dart';

void main() {
  group('GameStats', () {
    test('counts moves and keeps the biggest tile', () {
      var stats = const GameStats();
      stats = stats.withMove(8);
      stats = stats.withMove(64);
      stats = stats.withMove(32);
      expect(stats.totalMoves, 3);
      expect(stats.highestTile, 64);
    });

    test('games played never goes below zero', () {
      expect(const GameStats().withGamesPlayed(-1).gamesPlayed, 0);
    });

    test('survives a save and load', () {
      final stats = const GameStats(gamesPlayed: 4, totalMoves: 90, highestTile: 512);
      final loaded = GameStats.fromJson(stats.toJson());
      expect(loaded.gamesPlayed, 4);
      expect(loaded.totalMoves, 90);
      expect(loaded.highestTile, 512);
    });

    test('bad saved data gives empty stats', () {
      final loaded = GameStats.fromJson({'games': 'x', 'moves': -5});
      expect(loaded.gamesPlayed, 0);
      expect(loaded.totalMoves, 0);
    });
  });

  group('palettes', () {
    test('every theme has a style for every tile up to 2048', () {
      for (final palette in kPalettes) {
        expect(palette.tiles.length, 11, reason: palette.name);
      }
    });

    test('tiles above 2048 use the big tile style', () {
      for (final palette in kPalettes) {
        expect(palette.tileStyle(4096), same(palette.bigTile));
      }
    });

    test('the first tile is 2', () {
      for (final palette in kPalettes) {
        expect(palette.tileStyle(2), same(palette.tiles.first));
        expect(palette.tileStyle(2048), same(palette.tiles.last));
      }
    });
  });

  group('AppController', () {
    test('keeps settings and rejects a wrong theme number', () {
      final storage = GameStorage.inMemory();
      final controller = AppController(storage);
      controller.setTheme(2);
      controller.setSound(false);
      expect(controller.themeIndex, 2);
      expect(controller.soundOn, isFalse);

      final reopened = AppController(storage);
      expect(reopened.themeIndex, 2);
      expect(reopened.soundOn, isFalse);

      controller.setTheme(99);
      expect(controller.themeIndex, 0);
    });

    test('reset clears the best score and the stats', () {
      final controller = AppController(GameStorage.inMemory());
      controller.submitScore(GameConfig.standard, 500);
      controller.recordMove(highestTile: 64);
      controller.recordGameFinished();
      controller.resetStats();
      expect(controller.bestFor(GameConfig.standard), 0);
      expect(controller.stats.totalMoves, 0);
      expect(controller.stats.gamesPlayed, 0);
    });

    test('best scores are kept per mode and size', () {
      final controller = AppController(GameStorage.inMemory());
      const timed5 = GameConfig(GameMode.timed, 5);
      controller.submitScore(GameConfig.standard, 300);
      controller.submitScore(timed5, 900);
      controller.submitScore(timed5, 100);
      expect(controller.bestFor(GameConfig.standard), 300);
      expect(controller.bestFor(timed5), 900);
    });

    test('zen mode has no best score', () {
      final controller = AppController(GameStorage.inMemory());
      const zen = GameConfig(GameMode.zen, 4);
      controller.submitScore(zen, 5000);
      expect(controller.bestFor(zen), 0);
    });

    test('the chosen mode and size are remembered', () {
      final storage = GameStorage.inMemory();
      AppController(storage).setConfig(const GameConfig(GameMode.zen, 6));
      final reopened = AppController(storage);
      expect(reopened.config.mode, GameMode.zen);
      expect(reopened.config.size, 6);
    });
  });
}
