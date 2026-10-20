import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Saves the best score and the running game on the device. Nothing leaves it.
class GameStorage {
  GameStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _bestKey = 'best_score';
  static const String _gameKey = 'saved_game';

  int get best => _prefs.getInt(_bestKey) ?? 0;

  Future<void> saveBest(int value) => _prefs.setInt(_bestKey, value);

  Map<String, dynamic>? loadGame() {
    final raw = _prefs.getString(_gameKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGame(Map<String, dynamic> game) =>
      _prefs.setString(_gameKey, jsonEncode(game));
}
