import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves the settings, scores and the running game on the device. Nothing
/// leaves it.
///
/// Everything is kept in two places at once: the phone's SharedPreferences
/// and a small JSON file in the app's private folder. If one of them does not
/// work on a phone, the other one still keeps the progress. If neither works,
/// the game stays playable but [isPersistent] is false and Settings says so.
class GameStorage {
  /// Uses the given preferences only (no backup file). Handy in tests.
  GameStorage(SharedPreferences prefs) : this._(prefs, null, null);

  /// Keeps everything in memory only. Nothing is saved.
  GameStorage.inMemory() : this._(null, null, null);

  GameStorage._(this._prefs, this._file, Map<String, Object>? fileData) {
    _prefsOk = _prefs != null;
    _fileOk = _file != null;

    final fromPrefs = _readPrefs(_prefs);
    final prefsTime = _timeOf(fromPrefs);
    final fileTime = _timeOf(fileData);

    if (fileData != null && fileTime > prefsTime) {
      // The file is newer: the preferences were not saving for a while.
      _memory.addAll(fileData);
      _copyToPrefs();
    } else {
      _memory.addAll(fromPrefs);
      // First run with the backup file: fill it from the preferences, so
      // nothing that was saved by an older version is lost.
      if (_file != null) _scheduleFileWrite();
    }
  }

  /// Opens the storage. It waits for the phone, never gives up on the
  /// preferences too early, and falls back to the backup file.
  static Future<GameStorage> open() async {
    SharedPreferences? prefs;
    String prefsNote;
    try {
      prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 10));
      prefsNote = 'preferences: ok, ${prefs.getKeys().length} keys';
    } catch (e) {
      prefsNote = 'preferences: FAILED ($e)';
    }

    File? file;
    Map<String, Object>? fileData;
    String fileNote;
    try {
      final dir = await getApplicationSupportDirectory()
          .timeout(const Duration(seconds: 5));
      file = File('${dir.path}/pow2_data.json');
      fileData = await _readFile(file);
      fileNote = fileData == null
          ? 'file: ok, no data yet'
          : 'file: ok, ${fileData.length} keys';
    } catch (e) {
      file = null;
      fileNote = 'file: FAILED ($e)';
    }
    final storage = GameStorage._(prefs, file, fileData);
    storage._openNote = '$prefsNote\n$fileNote';
    return storage;
  }

  /// Same as [open] but with the places given (for tests).
  @visibleForTesting
  static Future<GameStorage> openWith({
    SharedPreferences? prefs,
    File? file,
  }) async {
    final fileData = file == null ? null : await _readFile(file);
    return GameStorage._(prefs, file, fileData);
  }

  final SharedPreferences? _prefs;
  final File? _file;
  final Map<String, Object> _memory = {};
  bool _prefsOk = false;
  bool _fileOk = false;
  bool _fileDirty = false;
  String _openNote = '';
  String _lastError = '';
  Future<void>? _fileJob;

  static const String _timeKey = '__saved_at';
  static const String _gameKey = 'saved_game';
  static const String _statsKey = 'stats';
  static const String _themeKey = 'theme_index';
  static const String _soundKey = 'sound_on';
  static const String _hapticsKey = 'haptics_on';
  static const String _modeKey = 'game_mode';
  static const String _sizeKey = 'board_size';
  static const String _dailyPlayedKey = 'daily_played';
  static const String _dailyBestDayKey = 'daily_best_day';
  static const String _dailyBestScoreKey = 'daily_best_score';
  static const String _achievementsKey = 'achievements';

  /// True when at least one place is saving. False means progress is lost
  /// when the app closes.
  bool get isPersistent => _prefsOk || _fileOk;

  /// Small technical details for Settings, to find out why saving fails.
  String get debugText {
    final parts = [
      if (_openNote.isNotEmpty) _openNote,
      if (_lastError.isNotEmpty) 'last error: $_lastError',
    ];
    return parts.isEmpty ? 'no details' : parts.join('\n');
  }

  String get statusText {
    if (_prefsOk && _fileOk) return 'Saved on this phone (two copies)';
    if (_prefsOk || _fileOk) return 'Saved on this phone';
    return 'This phone is not letting Pow2 save. Progress is lost when the '
        'app closes.';
  }

  static Map<String, Object> _readPrefs(SharedPreferences? prefs) {
    final out = <String, Object>{};
    if (prefs == null) return out;
    try {
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        if (value is int || value is bool || value is String) {
          out[key] = value!;
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<Map<String, Object>?> _readFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final out = <String, Object>{};
      decoded.forEach((key, value) {
        if (key is String && (value is int || value is bool || value is String)) {
          out[key] = value as Object;
        }
      });
      return out;
    } catch (_) {
      return null;
    }
  }

  static int _timeOf(Map<String, Object>? data) {
    final value = data?[_timeKey];
    return value is int ? value : 0;
  }

  Future<void> _putPrefs(SharedPreferences prefs, String key, Object value) async {
    if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _copyToPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;
    _memory.forEach((key, value) {
      _putPrefs(prefs, key, value).catchError((Object _) {
        _prefsOk = false;
      });
    });
  }

  T? _read<T>(String key) {
    final value = _memory[key];
    return value is T ? value : null;
  }

  Future<void> _write(String key, Object value) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _memory[key] = value;
    _memory[_timeKey] = now;
    final prefs = _prefs;
    if (prefs != null) {
      try {
        await _putPrefs(prefs, key, value);
        await _putPrefs(prefs, _timeKey, now);
        _prefsOk = true;
      } catch (e) {
        _prefsOk = false;
        _lastError = 'preferences write: $e';
      }
    }
    _scheduleFileWrite();
  }

  void _scheduleFileWrite() {
    if (_file == null) return;
    _fileDirty = true;
    _fileJob ??= _runFileJob();
  }

  Future<void> _runFileJob() async {
    try {
      while (_fileDirty) {
        _fileDirty = false;
        try {
          final target = _file!;
          final temp = File('${target.path}.tmp');
          await temp.writeAsString(jsonEncode(_memory), flush: true);
          await temp.rename(target.path);
          _fileOk = true;
        } catch (e) {
          _fileOk = false;
          _lastError = 'file write: $e';
        }
      }
    } finally {
      _fileJob = null;
    }
  }

  /// Waits until everything is written to the backup file.
  Future<void> flush() async {
    while (_fileJob != null) {
      await _fileJob;
    }
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

  /// Days (like 20261020) on which the daily challenge was played.
  Set<int> get dailyPlayed {
    final raw = _read<String>(_dailyPlayedKey) ?? '';
    return {
      for (final part in raw.split(','))
        if (int.tryParse(part) != null) int.parse(part),
    };
  }

  Future<void> saveDailyPlayed(Set<int> days) {
    final sorted = days.toList()..sort();
    final recent = sorted.length > 400 ? sorted.sublist(sorted.length - 400) : sorted;
    return _write(_dailyPlayedKey, recent.join(','));
  }

  /// Best score of the daily challenge for one day (0 for any other day).
  int dailyBest(int day) =>
      _read<int>(_dailyBestDayKey) == day ? _read<int>(_dailyBestScoreKey) ?? 0 : 0;

  Future<void> saveDailyBest(int day, int score) {
    // Both values go into memory at once; the disk writes follow.
    final dayWrite = _write(_dailyBestDayKey, day);
    final scoreWrite = _write(_dailyBestScoreKey, score);
    return Future.wait([dayWrite, scoreWrite]);
  }

  Set<String> get unlockedAchievements {
    final raw = _read<String>(_achievementsKey) ?? '';
    return {
      for (final part in raw.split(','))
        if (part.isNotEmpty) part,
    };
  }

  Future<void> saveUnlockedAchievements(Set<String> ids) =>
      _write(_achievementsKey, ids.join(','));
}
