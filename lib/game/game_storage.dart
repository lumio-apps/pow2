import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Saves the settings, scores and the running game on the device. Nothing
/// leaves it.
///
/// If the device storage can not be opened, [GameStorage.inMemory] keeps the
/// game playable (progress is just not saved).
class GameStorage {
  GameStorage(SharedPreferences prefs) : _prefs = prefs;

  GameStorage.inMemory() : _prefs = null;

  final SharedPreferences? _prefs;
  final Map<String, Object> _memory = {};

  static const String _gameKey = 'saved_game';
  static const String _statsKey = 'stats';
  static const String _themeKey = 'theme_index';
  static const String _soundKey = 'sound_on';
  static const String _hapticsKey = 'haptics_on';
  static const String _modeKey = 'game_mode';
  static const String _sizeKey = 'board_size';

  T? _read<T>(String key) {
    try {
      final value = _prefs?.get(key);
      if (value is T) return value;
    } catch (_) {}
    final fallback = _memory[key];
    return fallback is T ? fallback : null;
  }

  Future<void> _write(String key, Object value) async {
    _memory[key] = value;
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (_) {}
  }

  Map<String, dynamic>? _readJson(String key) {
    final raw = _read<String>(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  int bestScore(String key) => _read<int>(key) ?? 0;

  Future<void> saveBestScore(String key, int value) => _write(key, value);

  Map<String, dynamic>? loadGame() => _readJson(_gameKey);

  Future<void> saveGame(Map<String, dynamic> game) =>
      _write(_gameKey, jsonEncode(game));

  Map<String, dynamic>? loadStats() => _readJson(_statsKey);

  Future<void> saveStats(Map<String, dynamic> stats) =>
      _write(_statsKey, jsonEncode(stats));

  int get themeIndex => _read<int>(_themeKey) ?? 0;

  Future<void> saveThemeIndex(int value) => _write(_themeKey, value);

  bool get soundOn => _read<bool>(_soundKey) ?? true;

  Future<void> saveSoundOn(bool value) => _write(_soundKey, value);

  bool get hapticsOn => _read<bool>(_hapticsKey) ?? true;

  Future<void> saveHapticsOn(bool value) => _write(_hapticsKey, value);

  String get modeName => _read<String>(_modeKey) ?? 'classic';

  Future<void> saveModeName(String value) => _write(_modeKey, value);

  int get boardSize => _read<int>(_sizeKey) ?? 4;

  Future<void> saveBoardSize(int value) => _write(_sizeKey, value);
}
