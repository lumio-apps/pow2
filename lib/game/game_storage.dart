import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Saves the settings, scores and the running game on the device. Nothing
/// leaves it.
///
/// Everything lives in one small JSON file in the app's private folder. It is
/// written to a temporary file first and then renamed, so a crash in the
/// middle of a save can never leave a half written file behind.
///
/// Older versions (before 1.6.4) used the phone's SharedPreferences. On some
/// phones that plugin does not work in release builds, so it is not used any
/// more. If the old preferences file is still on the phone, it is read once
/// (as plain text) and its values are moved into the new file, so nothing
/// that was saved before is lost.
class GameStorage {
  /// Keeps everything in memory only. Nothing is saved.
  GameStorage.inMemory() : this._(null, null);

  GameStorage._(this._file, Map<String, Object>? loaded) {
    _fileOk = _file != null;
    if (loaded != null) _memory.addAll(loaded);
  }

  /// Opens the storage in the app's private folder.
  static Future<GameStorage> open() async {
    File? file;
    String note;
    Map<String, Object>? data;
    var imported = 0;
    try {
      final dir = await getApplicationSupportDirectory()
          .timeout(const Duration(seconds: 10));
      file = File('${dir.path}/pow2_data.json');
      data = await _readFile(file);
      if (data == null) {
        // First start of this version: look for data of an older version.
        final legacy = File(
          '${dir.parent.path}/shared_prefs/FlutterSharedPreferences.xml',
        );
        data = await _readLegacyPrefs(legacy);
        imported = data?.length ?? 0;
      }
      note = data == null ? 'file: ok, no data yet' : 'file: ok, ${data.length} keys';
    } catch (e) {
      file = null;
      note = 'file: FAILED (${_short(e)})';
    }
    final storage = GameStorage._(file, data);
    storage._openNote = imported > 0 ? '$note\nmoved $imported old values' : note;
    if (imported > 0) storage._scheduleFileWrite();
    return storage;
  }

  /// Same as [open] but with the places given (for tests).
  @visibleForTesting
  static Future<GameStorage> openWith({File? file, File? legacyPrefs}) async {
    var data = file == null ? null : await _readFile(file);
    if (data == null && legacyPrefs != null) {
      data = await _readLegacyPrefs(legacyPrefs);
    }
    final storage = GameStorage._(file, data);
    if (data != null && file != null) storage._scheduleFileWrite();
    return storage;
  }

  final File? _file;
  final Map<String, Object> _memory = {};
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

  /// True when progress is being saved. False means it is lost when the app
  /// closes.
  bool get isPersistent => _fileOk;

  /// Short technical details for Settings (only shown when saving fails).
  String get debugText {
    final parts = [
      if (_openNote.isNotEmpty) _openNote,
      if (_lastError.isNotEmpty) 'last error: $_lastError',
    ];
    return parts.isEmpty ? 'no details' : parts.join('\n');
  }

  String get statusText => _fileOk
      ? 'Saved on this phone'
      : 'This phone is not letting Pow2 save. Progress is lost when the app '
          'closes.';

  static String _short(Object error) {
    final text = error.toString().replaceAll('\n', ' ');
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
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

  /// Reads the preferences file of older versions as plain text. Returns null
  /// when it is missing or has nothing in it.
  static Future<Map<String, Object>?> _readLegacyPrefs(File file) async {
    try {
      if (!await file.exists()) return null;
      final out = parseLegacyPrefs(await file.readAsString());
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Turns the text of Android's FlutterSharedPreferences.xml into values.
  @visibleForTesting
  static Map<String, Object> parseLegacyPrefs(String xml) {
    const prefix = 'flutter.';
    final out = <String, Object>{};

    String unescape(String text) => text
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m[1]!)),
        )
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');

    final scalars = RegExp(
      r'<(int|long|boolean)\s+name="([^"]*)"\s+value="([^"]*)"\s*/>',
    );
    for (final m in scalars.allMatches(xml)) {
      final name = unescape(m[2]!);
      if (!name.startsWith(prefix)) continue;
      final key = name.substring(prefix.length);
      if (m[1] == 'boolean') {
        out[key] = m[3] == 'true';
      } else {
        final number = int.tryParse(m[3]!);
        if (number != null) out[key] = number;
      }
    }

    final strings = RegExp(
      r'<string\s+name="([^"]*)"\s*(?:/>|>([\s\S]*?)</string>)',
    );
    for (final m in strings.allMatches(xml)) {
      final name = unescape(m[1]!);
      if (!name.startsWith(prefix)) continue;
      out[name.substring(prefix.length)] = unescape(m[2] ?? '');
    }
    return out;
  }

  T? _read<T>(String key) {
    final value = _memory[key];
    return value is T ? value : null;
  }

  Future<void> _write(String key, Object value) async {
    _memory[key] = value;
    _memory[_timeKey] = DateTime.now().millisecondsSinceEpoch;
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
          _lastError = 'file write: ${_short(e)}';
        }
      }
    } finally {
      _fileJob = null;
    }
  }

  /// Waits until everything is written to the file.
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
