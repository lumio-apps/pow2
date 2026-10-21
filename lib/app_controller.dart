import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/achievements.dart';
import 'game/daily.dart';
import 'game/game_config.dart';
import 'game/game_stats.dart';
import 'game/game_storage.dart';
import 'theme.dart';

/// Settings, best scores and stats. Screens listen to it through [Pow2Scope].
class AppController extends ChangeNotifier {
  AppController(this.storage)
      : _themeIndex = _safeIndex(storage.themeIndex),
        _sound = storage.soundOn,
        _haptics = storage.hapticsOn,
        _stats = GameStats.fromJson(storage.loadStats()),
        _config = GameConfig(
          GameConfig.modeFromName(storage.modeName),
          GameConfig.safeSize(storage.boardSize),
        ),
        _dailyPlayed = storage.dailyPlayed,
        _unlocked = storage.unlockedAchievements;

  final GameStorage storage;

  int _themeIndex;
  bool _sound;
  bool _haptics;
  GameStats _stats;
  GameConfig _config;
  final Set<int> _dailyPlayed;
  final Set<String> _unlocked;
  final Map<String, int> _best = {};

  static int _safeIndex(int index) =>
      index < 0 || index >= kPalettes.length ? 0 : index;

  int get themeIndex => _themeIndex;
  Pow2Palette get palette => kPalettes[_themeIndex];
  bool get soundOn => _sound;
  bool get hapticsOn => _haptics;
  GameStats get stats => _stats;

  /// The mode and board size chosen for the next new game.
  GameConfig get config => _config;

  void setTheme(int index) {
    final safe = _safeIndex(index);
    if (safe == _themeIndex) return;
    _themeIndex = safe;
    storage.saveThemeIndex(safe);
    notifyListeners();
  }

  void setSound(bool value) {
    if (value == _sound) return;
    _sound = value;
    storage.saveSoundOn(value);
    notifyListeners();
  }

  void setHaptics(bool value) {
    if (value == _haptics) return;
    _haptics = value;
    storage.saveHapticsOn(value);
    notifyListeners();
  }

  void setConfig(GameConfig config) {
    _config = config;
    storage.saveModeName(config.mode.name);
    // The daily challenge is always 4x4, so it keeps the size you picked.
    if (config.mode != GameMode.daily) storage.saveBoardSize(config.size);
    notifyListeners();
  }

  /// Best score for one kind of game. Zen has none, so it returns 0.
  int bestFor(GameConfig config) {
    final key = config.bestKey;
    if (key == null) return 0;
    return _best.putIfAbsent(key, () => storage.bestScore(key));
  }

  /// Keeps the best score. No rebuild: the game screen redraws itself.
  void submitScore(GameConfig config, int score) {
    final key = config.bestKey;
    if (key == null || score <= bestFor(config)) return;
    _best[key] = score;
    storage.saveBestScore(key, score);
  }

  void recordMove({required int highestTile}) {
    _stats = _stats.withMove(highestTile);
    storage.saveStats(_stats.toJson());
  }

  void recordGameFinished() {
    _stats = _stats.withGamesPlayed(_stats.gamesPlayed + 1);
    storage.saveStats(_stats.toJson());
  }

  /// Best score of the daily challenge on [day].
  int dailyBest(int day) => storage.dailyBest(day);

  void submitDailyScore(int day, int score) {
    if (score <= dailyBest(day)) return;
    storage.saveDailyBest(day, score);
  }

  void markDailyPlayed(int day) {
    if (_dailyPlayed.add(day)) storage.saveDailyPlayed(_dailyPlayed);
  }

  int get dailyStreakNow => dailyStreak(_dailyPlayed, dayKey(DateTime.now()));

  int get dailyDaysPlayed => _dailyPlayed.length;

  Set<String> get unlockedIds => Set.unmodifiable(_unlocked);

  /// Unlocks every achievement whose rule is now true and returns the new ones.
  List<Achievement> checkAchievements({
    required GameConfig config,
    required int score,
    required int tile,
  }) {
    final earned = newlyEarned(
      AchievementContext(
        allTimeTile: _stats.highestTile,
        gamesPlayed: _stats.gamesPlayed,
        totalMoves: _stats.totalMoves,
        score: score,
        tile: tile,
        mode: config.mode,
        size: config.size,
        dailyDays: _dailyPlayed.length,
        dailyStreak: dailyStreakNow,
      ),
      _unlocked,
    );
    if (earned.isEmpty) return earned;
    _unlocked.addAll(earned.map((a) => a.id));
    storage.saveUnlockedAchievements(_unlocked);
    notifyListeners();
    return earned;
  }

  /// Used when a lost game is brought back with Undo.
  void unrecordGameFinished() {
    _stats = _stats.withGamesPlayed(_stats.gamesPlayed - 1);
    storage.saveStats(_stats.toJson());
  }

  /// Clears all best scores and all statistics.
  void resetStats() {
    _stats = const GameStats();
    storage.saveStats(_stats.toJson());
    for (final config in GameConfig.scored) {
      final key = config.bestKey;
      if (key != null) storage.saveBestScore(key, 0);
    }
    _best.clear();
    notifyListeners();
  }

  void mergeFeedback() {
    if (_sound) SystemSound.play(SystemSoundType.click);
    if (_haptics) HapticFeedback.lightImpact();
  }

  void milestoneFeedback() {
    if (_haptics) HapticFeedback.mediumImpact();
  }

  void gameOverFeedback() {
    if (_haptics) HapticFeedback.heavyImpact();
  }
}

/// Gives every screen access to the [AppController].
class Pow2Scope extends InheritedNotifier<AppController> {
  const Pow2Scope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<Pow2Scope>();
    assert(scope != null, 'Pow2Scope is missing above this widget');
    return scope!.notifier!;
  }
}

extension Pow2Context on BuildContext {
  AppController get app => Pow2Scope.of(this);

  Pow2Palette get palette => app.palette;
}
