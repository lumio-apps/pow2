import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pow2/game/game_storage.dart';
import 'package:pow2/main.dart';

void main() {
  testWidgets('shows the Pow2 game screen', (tester) async {
    await tester.pumpWidget(Pow2App(storage: GameStorage.inMemory()));

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    // Achievements, Stats and Settings sit together at the top.
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });
}
