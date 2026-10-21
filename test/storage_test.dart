import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/game/game_storage.dart';

const String _legacyXml = '''
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <int name="flutter.theme_index" value="3" />
    <long name="flutter.best_score" value="4000" />
    <boolean name="flutter.sound_on" value="false" />
    <string name="flutter.achievements">first_merge,reach_128</string>
    <string name="flutter.stats">{&quot;gamesPlayed&quot;:7,&quot;note&quot;:&quot;a &amp; b&quot;}</string>
    <string name="other_plugin_key">ignored</string>
</map>
''';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pow2_test');
    file = File('${dir.path}/pow2_data.json');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('saved values are still there after the app is opened again', () async {
    final first = await GameStorage.openWith(file: file);
    await first.saveThemeIndex(2);
    await first.saveBestScore('best_score', 1234);
    await first.flush();

    final second = await GameStorage.openWith(file: file);
    expect(second.themeIndex, 2);
    expect(second.bestScore('best_score'), 1234);
    expect(second.isPersistent, isTrue);
    expect(second.statusText, 'Saved on this phone');
  });

  test('a broken file is ignored and replaced', () async {
    await file.writeAsString('not json');
    final storage = await GameStorage.openWith(file: file);
    expect(storage.themeIndex, 0);
    await storage.saveThemeIndex(1);
    await storage.flush();
    expect((await GameStorage.openWith(file: file)).themeIndex, 1);
  });

  test('no temporary file is left behind', () async {
    final storage = await GameStorage.openWith(file: file);
    await storage.saveSoundOn(false);
    await storage.flush();
    expect(await File('${file.path}.tmp').exists(), isFalse);
    expect(await file.exists(), isTrue);
  });

  test('the file only holds plain values', () async {
    final storage = await GameStorage.openWith(file: file);
    await storage.saveUnlockedAchievements({'a', 'b'});
    await storage.flush();
    final saved = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(saved['achievements'], anyOf('a,b', 'b,a'));
  });

  test('values of the older preferences file are moved over once', () async {
    final legacy = File('${dir.path}/FlutterSharedPreferences.xml');
    await legacy.writeAsString(_legacyXml);

    final storage = await GameStorage.openWith(file: file, legacyPrefs: legacy);
    expect(storage.themeIndex, 3);
    expect(storage.bestScore('best_score'), 4000);
    expect(storage.soundOn, isFalse);
    expect(storage.unlockedAchievements, {'first_merge', 'reach_128'});
    expect(storage.loadStats(), {'gamesPlayed': 7, 'note': 'a & b'});

    await storage.flush();
    // The next start reads the new file, even when the old one is gone.
    await legacy.delete();
    final again = await GameStorage.openWith(file: file, legacyPrefs: legacy);
    expect(again.themeIndex, 3);
    expect(again.bestScore('best_score'), 4000);
  });

  test('the older preferences are not used when the new file has data',
      () async {
    final legacy = File('${dir.path}/FlutterSharedPreferences.xml');
    await legacy.writeAsString(_legacyXml);
    await file.writeAsString(jsonEncode({'theme_index': 1}));

    final storage = await GameStorage.openWith(file: file, legacyPrefs: legacy);
    expect(storage.themeIndex, 1);
    expect(storage.bestScore('best_score'), 0);
  });

  test('parseLegacyPrefs reads only the app values', () {
    final values = GameStorage.parseLegacyPrefs(_legacyXml);
    expect(values.keys, containsAll(['theme_index', 'best_score', 'sound_on']));
    expect(values.containsKey('other_plugin_key'), isFalse);
    expect(GameStorage.parseLegacyPrefs('<map></map>'), isEmpty);
    expect(GameStorage.parseLegacyPrefs('garbage'), isEmpty);
  });

  test('memory only storage reports that nothing is saved', () {
    final storage = GameStorage.inMemory();
    expect(storage.isPersistent, isFalse);
    expect(storage.statusText, contains('not letting'));
  });
}
