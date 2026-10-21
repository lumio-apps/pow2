import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/game/game_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('the backup file keeps data when preferences do not work', () async {
    final first = await GameStorage.openWith(file: file);
    await first.saveThemeIndex(2);
    await first.saveBestScore('best_score', 1234);
    await first.flush();

    final second = await GameStorage.openWith(file: file);
    expect(second.themeIndex, 2);
    expect(second.bestScore('best_score'), 1234);
    expect(second.isPersistent, isTrue);
  });

  test('old preferences data fills the backup file on the first run', () async {
    SharedPreferences.setMockInitialValues({
      'best_score': 4000,
      'theme_index': 3,
    });
    final prefs = await SharedPreferences.getInstance();

    final storage = await GameStorage.openWith(prefs: prefs, file: file);
    expect(storage.bestScore('best_score'), 4000);
    expect(storage.themeIndex, 3);

    await storage.flush();
    final saved = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(saved['best_score'], 4000);
    expect(saved['theme_index'], 3);
  });

  test('a newer backup file wins over stale preferences', () async {
    SharedPreferences.setMockInitialValues({
      'best_score': 100,
      '__saved_at': 5,
    });
    final prefs = await SharedPreferences.getInstance();
    await file.writeAsString(
      jsonEncode({'best_score': 900, '__saved_at': 9}),
    );

    final storage = await GameStorage.openWith(prefs: prefs, file: file);
    expect(storage.bestScore('best_score'), 900);
  });

  test('a broken backup file is ignored', () async {
    await file.writeAsString('not json');
    final storage = await GameStorage.openWith(file: file);
    expect(storage.themeIndex, 0);
    await storage.saveThemeIndex(1);
    await storage.flush();
    expect((await GameStorage.openWith(file: file)).themeIndex, 1);
  });

  test('memory only storage reports that nothing is saved', () {
    final storage = GameStorage.inMemory();
    expect(storage.isPersistent, isFalse);
    expect(storage.statusText, contains('not letting'));
  });
}
