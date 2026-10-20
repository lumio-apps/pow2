import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../format.dart';
import '../game/game_engine.dart';
import '../game/game_storage.dart';
import '../theme.dart';
import '../widgets/action_button.dart';
import '../widgets/board_view.dart';
import '../widgets/game_over_overlay.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

const double _swipeThreshold = 24;

const Map<int, String> _milestoneMessages = {
  256: 'Nice merge!',
  512: 'Great job!',
  1024: 'Amazing!',
  2048: 'Incredible!',
  4096: 'Legendary!',
  8192: 'Unreal!',
};

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameEngine _engine = GameEngine();
  List<Tile> _dying = const <Tile>[];
  bool _gameOver = false;
  bool _bannerVisible = false;
  String _bannerText = '';
  Timer? _dyingTimer;
  Timer? _bannerTimer;
  double _dx = 0;
  double _dy = 0;
  bool _swipeHandled = false;

  AppController get _app => widget.controller;
  GameStorage get _storage => widget.controller.storage;

  @override
  void initState() {
    super.initState();
    final saved = _storage.loadGame();
    if (saved == null || !_engine.restore(saved)) {
      _engine.reset();
    }
    _gameOver = _engine.isGameOver;
  }

  @override
  void dispose() {
    _dyingTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _move(Direction direction) {
    if (_gameOver) return;
    final result = _engine.move(direction);
    if (!result.moved) return;

    final milestone = _engine.takeMilestone();
    final over = _engine.isGameOver;
    _dyingTimer?.cancel();
    _app.submitScore(_engine.score);
    _app.recordMove(highestTile: _engine.highestTile);

    setState(() {
      _dying = result.removed;
      _gameOver = over;
      if (milestone != null) {
        _bannerText = _milestoneMessages[milestone] ?? 'Great job!';
        _bannerVisible = true;
      }
    });

    if (result.removed.isNotEmpty) {
      _app.mergeFeedback();
      _dyingTimer = Timer(const Duration(milliseconds: 130), () {
        if (mounted) setState(() => _dying = const <Tile>[]);
      });
    }
    if (milestone != null) {
      _app.milestoneFeedback();
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _bannerVisible = false);
      });
    }
    if (over) {
      _app.recordGameFinished();
      _app.gameOverFeedback();
    }
    _storage.saveGame(_engine.toJson());
  }

  void _undo() {
    final wasOver = _gameOver;
    if (!_engine.undo()) return;
    if (wasOver) _app.unrecordGameFinished();
    _dyingTimer?.cancel();
    setState(() {
      _dying = const <Tile>[];
      _gameOver = false;
    });
    _storage.saveGame(_engine.toJson());
  }

  void _newGame() {
    // A game that was started but not lost still counts as played.
    if (!_gameOver && _engine.score > 0) _app.recordGameFinished();
    _dyingTimer?.cancel();
    _bannerTimer?.cancel();
    setState(() {
      _engine.reset();
      _dying = const <Tile>[];
      _gameOver = false;
      _bannerVisible = false;
    });
    _storage.saveGame(_engine.toJson());
  }

  Future<void> _confirmNewGame() async {
    if (_gameOver || _engine.score == 0) {
      _newGame();
      return;
    }
    final p = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.dialog,
        title: const Text('Start a new game?'),
        content: const Text('Your current game will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('New game'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _newGame();
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_swipeHandled) return;
    _dx += details.delta.dx;
    _dy += details.delta.dy;
    if (_dx.abs() < _swipeThreshold && _dy.abs() < _swipeThreshold) return;
    _swipeHandled = true;
    if (_dx.abs() > _dy.abs()) {
      _move(_dx > 0 ? Direction.right : Direction.left);
    } else {
      _move(_dy > 0 ? Direction.down : Direction.up);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _move(Direction.left);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _move(Direction.right);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(Direction.up);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _move(Direction.down);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            _dx = 0;
            _dy = 0;
            _swipeHandled = false;
          },
          onPanUpdate: _onPanUpdate,
          child: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    children: [
                      _Header(
                        palette: p,
                        score: _engine.score,
                        best: _app.best,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'Merge the tiles and ',
                                children: [
                                  TextSpan(
                                    text: 'keep growing',
                                    style: TextStyle(
                                      color: p.accentText,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: p.mutedText,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Stats',
                            onPressed: _openStats,
                            color: p.mutedText,
                            icon: const Icon(Icons.bar_chart_rounded),
                          ),
                          IconButton(
                            tooltip: 'Settings',
                            onPressed: _openSettings,
                            color: p.mutedText,
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: BoardView(
                            tiles: _engine.tiles,
                            dying: _dying,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ActionButton(
                              label: 'Undo',
                              icon: Icons.undo_rounded,
                              onPressed: _engine.canUndo ? _undo : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ActionButton(
                              label: 'New game',
                              icon: Icons.refresh_rounded,
                              primary: true,
                              onPressed: _confirmNewGame,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Swipe anywhere to move the tiles',
                        style: TextStyle(fontSize: 13, color: p.mutedText),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Offline · No ads · No tracking',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.3,
                          color: p.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _bannerVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: AnimatedScale(
                        scale: _bannerVisible ? 1 : 0.8,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        child: _MilestoneBanner(palette: p, text: _bannerText),
                      ),
                    ),
                  ),
                ),
              ),
              if (_gameOver)
                Positioned.fill(
                  child: GameOverOverlay(
                    score: _engine.score,
                    bestTile: _engine.highestTile,
                    canUndo: _engine.canUndo,
                    onNewGame: _newGame,
                    onUndo: _undo,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.score,
    required this.best,
  });

  final Pow2Palette palette;
  final int score;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text.rich(
          TextSpan(
            text: 'Pow',
            children: [
              TextSpan(text: '2', style: TextStyle(color: palette.accentText)),
            ],
          ),
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: palette.text,
          ),
        ),
        Row(
          children: [
            _ScoreBox(
              palette: palette,
              label: 'SCORE',
              value: formatNumber(score),
              valueColor: palette.text,
            ),
            const SizedBox(width: 8),
            _ScoreBox(
              palette: palette,
              label: 'BEST',
              value: formatNumber(best),
              valueColor: palette.accentText,
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.palette,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final Pow2Palette palette;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: palette.mutedText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneBanner extends StatelessWidget {
  const _MilestoneBanner({required this.palette, required this.text});

  final Pow2Palette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: palette.onAccent),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: palette.onAccent,
            ),
          ),
        ],
      ),
    );
  }
}
