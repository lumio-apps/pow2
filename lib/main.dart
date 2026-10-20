import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/game_storage.dart';
import 'screens/game_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Pow2Colors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(Pow2App(storage: GameStorage(prefs)));
}

class Pow2App extends StatelessWidget {
  const Pow2App({super.key, required this.storage});

  final GameStorage storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pow2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Pow2Colors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Pow2Colors.gold,
          brightness: Brightness.dark,
        ),
      ),
      home: GameScreen(storage: storage),
    );
  }
}
