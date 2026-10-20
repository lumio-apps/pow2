import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/game_storage.dart';
import 'screens/game_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If something breaks while drawing, show the error on screen instead of
  // a blank screen, so it can be reported.
  ErrorWidget.builder = (details) => ColoredBox(
        color: Pow2Colors.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              details.exceptionAsString(),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Pow2Colors.text,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      );

  try {
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
  } catch (_) {
    // Cosmetic only. The game works without it.
  }

  // Draw the first frame right away. The saved data loads afterwards, so a
  // slow or broken storage can never keep the app on the splash screen.
  runApp(const _Pow2Loader());
}

/// Shows a plain dark screen, loads the saved data (max 3 seconds), then
/// starts the game. If the storage fails, the game still starts, just
/// without saving.
class _Pow2Loader extends StatefulWidget {
  const _Pow2Loader();

  @override
  State<_Pow2Loader> createState() => _Pow2LoaderState();
}

class _Pow2LoaderState extends State<_Pow2Loader> {
  GameStorage? _storage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    GameStorage storage;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      storage = GameStorage(prefs);
    } catch (_) {
      storage = GameStorage.inMemory();
    }
    if (mounted) setState(() => _storage = storage);
  }

  @override
  Widget build(BuildContext context) {
    final storage = _storage;
    if (storage != null) return Pow2App(storage: storage);
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Pow2Colors.background,
        child: Center(
          child: Text(
            'Pow2',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Pow2Colors.text,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
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
