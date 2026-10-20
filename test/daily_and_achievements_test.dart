import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/app_controller.dart';
import 'package:pow2/game/achievements.dart';
import 'package:pow2/game/daily.dart';
import 'package:pow2/game/game_config.dart';
import 'package:pow2/game/game_storage.dart';

AchievementContext ctx({
  int allTimeTile = 0,
  int gamesPlayed = 0,
  int totalMoves = 0,
  int score = 0,
  int tile = 0,
  GameMode mode = GameMode.classic,
  int size = 4,
  int dailyDays = 0,
  int dailyStreak = 0,
}) =>
    AchievementContext(
      allTimeTile: allTimeTile,
      gamesPlayed: gamesPlayed,
      totalMoves: totalMoves,
      score: score,
      tile: tile,
      mode: mode,
      size: size,
      dailyDays: dailyDays,
      dailyStreak: dailyStreak,
    );

void main() {
  group('daily', () {
    test('day keys and the day before', () {
      expect(dayKey(DateTime(2026, 10, 20)), 20261020);
      expect(previousDay(20261101), 20261031);
      expect(previousDay(20260101), 20251231);
    });

    test('streak counts days in a row', () {
      expect(dailyStreak({20261018, 20261019, 20261020}, 20261020), 3);
      expect(dailyStreak({20261018, 20261019}, 20261020), 2);
      expect(dailyStreak({20261015, 20261020}, 20261020), 1);
      expect(dailyStreak({}, 20261020), 0);
    });

    test('daily is always 4x4', () {
      expect(const GameConfig(GameMode.daily, 6).size, 4);
      expect(GameConfig.dailyChallenge.bestKey, isNull);
    });
  });

  group('achievements', () {
    test('every achievement has a unique id', () {
      final ids = kAchievements.map((a) => a.id).toSet();
      expect(ids.length, kAchievements.length);
    });

    test('a new 128 tile unlocks Warm-up once', () {
      final first = newlyEarned(ctx(allTimeTile: 128), {});
      expect(first.map((a) => a.id), contains('tile128'));
      final again = newlyEarned(ctx(allTimeTile: 128), {'tile128'});
      expect(again.map((a) => a.id), isNot(contains('tile128')));
    });

    test('mode and size rules', () {
      final zen = newlyEarned(ctx(mode: GameMode.zen, tile: 512), {});
      expect(zen.map((a) => a.id), contains('zen512'));
      final big = newlyEarned(ctx(size: 6, tile: 512), {});
      expect(big.map((a) => a.id), contains('big512'));
      final streak = newlyEarned(ctx(dailyDays: 3, dailyStreak: 3), {});
      expect(streak.map((a) => a.id), containsAll(['daily1', 'streak3']));
    });

    test('the controller keeps unlocked achievements', () {
      final storage = GameStorage.inMemory();
      final controller = AppController(storage);
      controller.recordMove(highestTile: 256);
      final earned = controller.checkAchievements(
        config: GameConfig.standard,
        score: 6000,
        tile: 256,
      );
      expect(earned.map((a) => a.id), containsAll(['tile128', 'score5000']));
      expect(AppController(storage).unlockedIds, contains('tile128'));
      expect(
        controller.checkAchievements(
          config: GameConfig.standard,
          score: 6000,
          tile: 256,
        ),
        isEmpty,
      );
    });

    test('daily best is kept per day', () {
      final controller = AppController(GameStorage.inMemory());
      controller.submitDailyScore(20261020, 400);
      controller.submitDailyScore(20261020, 100);
      expect(controller.dailyBest(20261020), 400);
      expect(controller.dailyBest(20261021), 0);
    });
  });
}
