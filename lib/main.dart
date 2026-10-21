import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'game/game_storage.dart';
import 'screens/game_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If something breaks while drawing, show the error on screen instead of
  // a blank screen, so it can be reported.
  ErrorWidget.builder = (details) => ColoredBox(
        color: kSplashBackground,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              details.exceptionAsString(),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: kSplashText,
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
  } catch (_) {
    // Cosmetic only. The game works without it.
  }

  // Draw the first frame right away. The saved data loads afterwards, so a
  // slow or broken storage can never keep the app on the splash screen.
  runApp(const _Pow2Loader());
}

/// Shows a plain dark screen, loads the saved data, then starts the game.
/// If the storage fails, the game still starts, just without saving.
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
      storage = await GameStorage.open();
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
        color: kSplashBackground,
        child: Center(
          child: Text(
            'Pow2',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: kSplashText,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class Pow2App extends StatefulWidget {
  const Pow2App({super.key, required this.storage});

  final GameStorage storage;

  @override
  State<Pow2App> createState() => _Pow2AppState();
}

class _Pow2AppState extends State<Pow2App> {
  late final AppController _controller = AppController(widget.storage);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ThemeData _themeFor(Pow2Palette p) {
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
    ).copyWith(
      primary: p.accentText,
      onPrimary: p.isDark ? p.onAccent : Colors.white,
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.mutedText,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pow2Scope(
      controller: _controller,
      child: Builder(
        builder: (context) {
          final p = context.palette;
          final iconBrightness = p.isDark ? Brightness.light : Brightness.dark;
          return MaterialApp(
            title: 'Pow2',
            debugShowCheckedModeBanner: false,
            theme: _themeFor(p),
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: iconBrightness,
                systemNavigationBarColor: p.background,
                systemNavigationBarIconBrightness: iconBrightness,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
            home: GameScreen(controller: _controller),
          );
        },
      ),
    );
  }
}
