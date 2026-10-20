import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Saves the best score and the running game on the device. Nothing leaves it.
///
/// If the device storage can not be opened, [GameStorage.inMemory] keeps the
/// game playable (progress is just not saved).
class GameStorage {
  GameStorage(SharedPreferences prefs) : _prefs = prefs;

  GameStorage.inMemory() : _prefs = null;

  final SharedPreferences? _prefs;

  static const String _bestKey = 'best_score';
  static const String _gameKey = 'saved_game';

  int _bestInMemory = 0;
  String? _gameInMemory;

  int get best {
    try {
      return _prefs?.getInt(_bestKey) ?? _bestInMemory;
    } catch (_) {
      return _bestInMemory;
    }
  }

  Future<void> saveBest(int value) async {
    _bestInMemory = value;
    try {
      await _prefs?.setInt(_bestKey, value);
    } catch (_) {}
  }

  Map<String, dynamic>? loadGame() {
    String? raw;
    try {
      raw = _prefs?.getString(_gameKey) ?? _gameInMemory;
    } catch (_) {
      raw = _gameInMemory;
    }
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGame(Map<String, dynamic> game) async {
    final raw = jsonEncode(game);
    _gameInMemory = raw;
    try {
      await _prefs?.setString(_gameKey, raw);
    } catch (_) {}
  }
}
