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
  });
}
