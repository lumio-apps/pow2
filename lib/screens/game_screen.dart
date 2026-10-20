import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_controller.dart';
import '../format.dart';
import '../game/daily.dart';
import '../game/game_config.dart';
import '../game/game_engine.dart';
import '../game/game_storage.dart';
import '../share_card.dart';
import '../theme.dart';
import '../widgets/action_button.dart';
import '../widgets/board_view.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/setup_sheet.dart';
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

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameConfig _config;
  late GameEngine _engine;
  int _secondsLeft = GameConfig.timedSeconds;
  bool _timeUp = false;
  bool _gameOver = false;
  int _gameNumber = 0;
  List<Tile> _dying = const <Tile>[];
  bool _bannerVisible = false;
  String _bannerText = '';
  Timer? _dyingTimer;
  Timer? _bannerTimer;
  Timer? _ticker;
  int _dailyDay = 0;
  List<int> _dirs = [];
  final List<String> _noticeQueue = [];
  bool _inBackground = false;
  double _dx = 0;
  double _dy = 0;
  bool _swipeHandled = false;

  AppController get _app => widget.controller;
  GameStorage get _storage => widget.controller.storage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGame();
  }

  GameEngine _dailyEngine(int day) =>
      GameEngine(size: 4, random: Random(day))..reset();

  /// Continues the saved game, or starts a new one with the chosen settings.
  void _loadGame() {
    var config = _app.config;
    GameEngine? engine;
    final today = dayKey(DateTime.now());
    _dailyDay = today;
    _dirs = [];
    final saved = _storage.loadGame();
    if (saved != null) {
      if (saved['mode'] == GameMode.daily.name) {
        // A daily game is rebuilt by playing the saved swipes again on the
        // board of that day. A game from an older day is dropped.
        final dirs = saved['dirs'];
        if (saved['day'] == today && dirs is List) {
          final replayed = _dailyEngine(today);
          final list = <int>[];
          for (final d in dirs) {
            if (d is int && d >= 0 && d < Direction.values.length) {
              replayed.move(Direction.values[d]);
              list.add(d);
            }
          }
          replayed.takeMilestone();
          engine = replayed;
          _dirs = list;
          config = GameConfig.dailyChallenge;
        }
      } else {
        final savedSize = saved['size'];
        final size = savedSize is int ? savedSize : 4;
        if (GameConfig.sizes.contains(size)) {
          final candidate = GameEngine(size: size);
          if (candidate.restore(saved)) {
            engine = candidate;
            final modeName = saved['mode'];
            config = GameConfig(
              GameConfig.modeFromName(modeName is String ? modeName : null),
              size,
            );
            final secs = saved['secs'];
            if (secs is int) {
              _secondsLeft = secs.clamp(0, GameConfig.timedSeconds);
            }
          }
        }
      }
    }
    if (engine == null) {
      engine = config.mode == GameMode.daily
          ? _dailyEngine(today)
          : (GameEngine(size: config.size)..reset());
      _secondsLeft = GameConfig.timedSeconds;
    }
    _config = config;
    _engine = engine;
    _timeUp = config.mode == GameMode.timed && _secondsLeft <= 0;
    if (config.mode == GameMode.zen && engine.isGameOver) {
      engine.clearSmallest();
    }
    _gameOver = _timeUp || (config.mode != GameMode.zen && engine.isGameOver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dyingTimer?.cancel();
    _bannerTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inBackground = state != AppLifecycleState.resumed;
    if (_inBackground) _saveGame();
  }

  void _saveGame() {
    _storage.saveGame({
      ..._engine.toJson(),
      'mode': _config.mode.name,
      'secs': _secondsLeft,
      if (_config.mode == GameMode.daily) ...{'day': _dailyDay, 'dirs': _dirs},
    });
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _inBackground || _gameOver) return;
      setState(() => _secondsLeft = max(0, _secondsLeft - 1));
      if (_secondsLeft == 0) _onTimeUp();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTimeUp() {
    _stopTicker();
    setState(() {
      _timeUp = true;
      _gameOver = true;
    });
    _app.recordGameFinished();
    _app.gameOverFeedback();
    _showNotices(_achievementNotices());
    _saveGame();
  }

  List<String> _achievementNotices() => [
        for (final a in _app.checkAchievements(
          config: _config,
          score: _engine.score,
          tile: _engine.highestTile,
        ))
          'Achievement: ${a.title}',
      ];

  /// Shows messages one after the other in the banner.
  void _showNotices(List<String> notices) {
    if (notices.isEmpty) return;
    final idle = _noticeQueue.isEmpty && !_bannerVisible;
    _noticeQueue.addAll(notices);
    if (idle) _nextNotice();
  }

  void _nextNotice() {
    _bannerTimer?.cancel();
    if (!mounted) return;
    if (_noticeQueue.isEmpty) {
      setState(() => _bannerVisible = false);
      return;
    }
    final text = _noticeQueue.removeAt(0);
    setState(() {
      _bannerText = text;
      _bannerVisible = true;
    });
    _bannerTimer = Timer(const Duration(milliseconds: 2200), _nextNotice);
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await renderShareCard(
        palette: _app.palette,
        score: _engine.score,
        tile: _engine.highestTile,
        modeLabel: _config.label,
      );
      await SharePlus.instance.share(
        ShareParams(
          text: 'I scored ${formatNumber(_engine.score)} in Pow2 '
              '(${_config.label}). github.com/lumio-apps/pow2',
          files: [
            XFile.fromData(bytes, name: 'pow2-score.png', mimeType: 'image/png'),
          ],
          fileNameOverrides: const ['pow2-score.png'],
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open the share sheet")),
      );
    }
  }

  void _move(Direction direction) {
    if (_gameOver) return;
    final result = _engine.move(direction);
    if (!result.moved) return;

    if (_config.mode == GameMode.daily) {
      _dirs.add(direction.index);
      _app.markDailyPlayed(_dailyDay);
      _app.submitDailyScore(_dailyDay, _engine.score);
    } else {
      _app.submitScore(_config, _engine.score);
    }
    final milestone = _engine.takeMilestone();
    _dyingTimer?.cancel();
    _app.recordMove(highestTile: _engine.highestTile);

    final notices = <String>[];
    if (milestone != null) {
      notices.add(_milestoneMessages[milestone] ?? 'Great job!');
    }
    var over = false;
    if (_engine.isGameOver) {
      if (_config.mode == GameMode.zen) {
        _engine.clearSmallest();
        notices.add('Board full: smallest tiles cleared');
      } else {
        over = true;
      }
    }
    if (over) {
      _stopTicker();
      _app.recordGameFinished();
    } else if (_config.mode == GameMode.timed) {
      _startTicker();
    }
    notices.addAll(_achievementNotices());

    setState(() {
      _dying = result.removed;
      _gameOver = over;
    });
    _showNotices(notices);

    if (result.removed.isNotEmpty) {
      _app.mergeFeedback();
      _dyingTimer = Timer(const Duration(milliseconds: 130), () {
        if (mounted) setState(() => _dying = const <Tile>[]);
      });
    }
    if (milestone != null) _app.milestoneFeedback();
    if (over) _app.gameOverFeedback();
    _saveGame();
  }

  void _undo() {
    if (_timeUp || _config.mode == GameMode.daily) return;
    final wasOver = _gameOver;
    if (!_engine.undo()) return;
    if (wasOver) _app.unrecordGameFinished();
    _dyingTimer?.cancel();
    setState(() {
      _dying = const <Tile>[];
      _gameOver = false;
    });
    if (wasOver && _config.mode == GameMode.timed && _secondsLeft > 0) {
      _startTicker();
    }
    _saveGame();
  }

  void _startNew(GameConfig config) {
    // A game that was started but not finished still counts as played.
    if (!_gameOver && _engine.score > 0) _app.recordGameFinished();
    _stopTicker();
    _dyingTimer?.cancel();
    _bannerTimer?.cancel();
    _noticeQueue.clear();
    _dailyDay = dayKey(DateTime.now());
    _dirs = [];
    setState(() {
      _config = config;
      _engine = config.mode == GameMode.daily
          ? _dailyEngine(_dailyDay)
          : (GameEngine(size: config.size)..reset());
      _secondsLeft = GameConfig.timedSeconds;
      _timeUp = false;
      _gameOver = false;
      _dying = const <Tile>[];
      _bannerVisible = false;
      _gameNumber++;
    });
    _saveGame();
  }

  Future<void> _confirmNewGame() async {
    if (_gameOver || _engine.score == 0) {
      _startNew(_config);
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
    if (confirmed == true && mounted) _startNew(_config);
  }

  Future<void> _openSetup() async {
    final chosen = await showModalBottomSheet<GameConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.dialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SetupSheet(initial: _config),
    );
    if (chosen == null || !mounted) return;
    _app.setConfig(chosen);
    _startNew(chosen);
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

  String _formatTime(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isZen = _config.mode == GameMode.zen;
    final isTimed = _config.mode == GameMode.timed;
    final isDaily = _config.mode == GameMode.daily;
    final undoDepth = _engine.undoDepth;
    final lowTime = isTimed && _secondsLeft <= 10;

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
                        secondLabel: isZen ? 'TILE' : 'BEST',
                        secondValue: isZen
                            ? '${_engine.highestTile}'
                            : formatNumber(
                                isDaily
                                    ? _app.dailyBest(_dailyDay)
                                    : _app.bestFor(_config),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Semantics(
                            button: true,
                            label: 'Change mode and board size',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _openSetup,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: p.mutedText.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _config.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: p.text,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.expand_more_rounded,
                                        size: 18,
                                        color: p.mutedText,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (isDaily) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 20,
                              color: p.accentText,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${_app.dailyStreakNow}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: p.text,
                              ),
                            ),
                          ],
                          if (isTimed) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: lowTime
                                  ? const Color(0xFFD6453D)
                                  : p.accentText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(_secondsLeft),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: lowTime
                                    ? const Color(0xFFD6453D)
                                    : p.text,
                              ),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            tooltip: 'Stats',
                            onPressed: _openStats,
                            color: p.mutedText,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.bar_chart_rounded),
                          ),
                          IconButton(
                            tooltip: 'Settings',
                            onPressed: _openSettings,
                            color: p.mutedText,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: BoardView(
                            key: ValueKey(_gameNumber),
                            size: _engine.size,
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
                              label: undoDepth > 0 && !isDaily ? 'Undo ($undoDepth)' : 'Undo',
                              icon: Icons.undo_rounded,
                              onPressed: _engine.canUndo && !isDaily ? _undo : null,
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
                        isTimed && _ticker == null && !_gameOver
                            ? 'The clock starts with your first move'
                            : isDaily
                                ? 'Same board for everyone today · no undo'
                                : 'Swipe anywhere to move the tiles',
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
                    title: _timeUp ? "Time's up" : 'No moves left',
                    score: _engine.score,
                    bestTile: _engine.highestTile,
                    canUndo: _engine.canUndo && !_timeUp && !isDaily,
                    onNewGame: () => _startNew(_config),
                    onUndo: _undo,
                    onShare: _share,
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
    required this.secondLabel,
    required this.secondValue,
  });

  final Pow2Palette palette;
  final int score;
  final String secondLabel;
  final String secondValue;

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
              label: secondLabel,
              value: secondValue,
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: palette.onAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
