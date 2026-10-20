import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../game/game_engine.dart';
import '../game/game_storage.dart';
import '../theme.dart';
import '../update_flow.dart';
import '../widgets/action_button.dart';
import '../widgets/board_view.dart';
import '../widgets/game_over_overlay.dart';

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
  const GameScreen({super.key, required this.storage});

  final GameStorage storage;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameEngine _engine = GameEngine();
  late int _best;
  List<Tile> _dying = const <Tile>[];
  bool _gameOver = false;
  bool _bannerVisible = false;
  String _bannerText = '';
  Timer? _dyingTimer;
  Timer? _bannerTimer;
  double _dx = 0;
  double _dy = 0;
  bool _swipeHandled = false;

  @override
  void initState() {
    super.initState();
    _best = widget.storage.best;
    final saved = widget.storage.loadGame();
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
    _dyingTimer?.cancel();
    setState(() {
      _dying = result.removed;
      if (_engine.score > _best) {
        _best = _engine.score;
        widget.storage.saveBest(_best);
      }
      _gameOver = _engine.isGameOver;
      if (milestone != null) {
        _bannerText = _milestoneMessages[milestone] ?? 'Great job!';
        _bannerVisible = true;
      }
    });

    if (result.removed.isNotEmpty) {
      HapticFeedback.lightImpact();
      _dyingTimer = Timer(const Duration(milliseconds: 130), () {
        if (mounted) setState(() => _dying = const <Tile>[]);
      });
    }
    if (milestone != null) {
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _bannerVisible = false);
      });
    }
    widget.storage.saveGame(_engine.toJson());
  }

  void _undo() {
    if (!_engine.undo()) return;
    _dyingTimer?.cancel();
    setState(() {
      _dying = const <Tile>[];
      _gameOver = false;
    });
    widget.storage.saveGame(_engine.toJson());
  }

  void _newGame() {
    _dyingTimer?.cancel();
    _bannerTimer?.cancel();
    setState(() {
      _engine.reset();
      _dying = const <Tile>[];
      _gameOver = false;
      _bannerVisible = false;
    });
    widget.storage.saveGame(_engine.toJson());
  }

  Future<void> _confirmNewGame() async {
    if (_gameOver || _engine.score == 0) {
      _newGame();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Pow2Colors.panel,
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
    return Scaffold(
      backgroundColor: Pow2Colors.background,
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
                      _Header(score: _engine.score, best: _best),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          const TextSpan(
                            text: 'Merge the tiles and ',
                            children: [
                              TextSpan(
                                text: 'keep growing',
                                style: TextStyle(
                                  color: Pow2Colors.gold,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Pow2Colors.mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                      const Text(
                        'Swipe anywhere to move the tiles',
                        style: TextStyle(
                          fontSize: 13,
                          color: Pow2Colors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Offline · No ads · No tracking',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.3,
                          color: Pow2Colors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () => checkForUpdates(context),
                        icon: const Icon(Icons.system_update_outlined, size: 16),
                        label: const Text('Check for updates'),
                        style: TextButton.styleFrom(
                          foregroundColor: Pow2Colors.mutedText,
                          textStyle: const TextStyle(fontSize: 12),
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
                        child: _MilestoneBanner(text: _bannerText),
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
  const _Header({required this.score, required this.best});

  final int score;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text.rich(
          TextSpan(
            text: 'Pow',
            children: [
              TextSpan(text: '2', style: TextStyle(color: Pow2Colors.gold)),
            ],
          ),
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: Pow2Colors.text,
          ),
        ),
        Row(
          children: [
            _ScoreBox(
              label: 'SCORE',
              value: formatNumber(score),
              valueColor: Pow2Colors.text,
            ),
            const SizedBox(width: 8),
            _ScoreBox(
              label: 'BEST',
              value: formatNumber(best),
              valueColor: Pow2Colors.gold,
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Pow2Colors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: Pow2Colors.mutedText,
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
  const _MilestoneBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Pow2Colors.gold,
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
          const Icon(Icons.star_rounded, color: Pow2Colors.dark),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Pow2Colors.dark,
            ),
          ),
        ],
      ),
    );
  }
}
