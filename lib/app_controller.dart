import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_stats.dart';
import 'game/game_storage.dart';
import 'theme.dart';

/// Settings, best score and stats. Screens listen to it through [Pow2Scope].
class AppController extends ChangeNotifier {
  AppController(this.storage)
      : _themeIndex = _safeIndex(storage.themeIndex),
        _sound = storage.soundOn,
        _haptics = storage.hapticsOn,
        _stats = GameStats.fromJson(storage.loadStats()),
        _best = storage.best;

  final GameStorage storage;

  int _themeIndex;
  bool _sound;
  bool _haptics;
  GameStats _stats;
  int _best;

  static int _safeIndex(int index) =>
      index < 0 || index >= kPalettes.length ? 0 : index;

  int get themeIndex => _themeIndex;
  Pow2Palette get palette => kPalettes[_themeIndex];
  bool get soundOn => _sound;
  bool get hapticsOn => _haptics;
  GameStats get stats => _stats;
  int get best => _best;

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

  /// Keeps the best score. No rebuild: the game screen redraws itself.
  void submitScore(int score) {
    if (score <= _best) return;
    _best = score;
    storage.saveBest(score);
  }

  void recordMove({required int highestTile}) {
    _stats = _stats.withMove(highestTile);
    storage.saveStats(_stats.toJson());
  }

  void recordGameFinished() {
    _stats = _stats.withGamesPlayed(_stats.gamesPlayed + 1);
    storage.saveStats(_stats.toJson());
  }

  /// Used when a lost game is brought back with Undo.
  void unrecordGameFinished() {
    _stats = _stats.withGamesPlayed(_stats.gamesPlayed - 1);
    storage.saveStats(_stats.toJson());
  }

  /// Clears the best score and all statistics.
  void resetStats() {
    _stats = const GameStats();
    _best = 0;
    storage.saveStats(_stats.toJson());
    storage.saveBest(0);
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
