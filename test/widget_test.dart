import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/game/game_storage.dart';
import 'package:pow2/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the Pow2 game screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(Pow2App(storage: GameStorage(prefs)));

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    // Achievements, Stats and Settings sit together at the top.
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });
}
