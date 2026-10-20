import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_controller.dart';
import '../format.dart';
import '../page_route.dart';
import '../game/daily.dart';
import '../game/game_config.dart';
import '../game/game_engine.dart';
import '../game/game_storage.dart';
import '../game/hint.dart';
import '../share_card.dart';
import '../theme.dart';
import '../widgets/action_button.dart';
import '../widgets/board_view.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/press_scale.dart';
import '../widgets/setup_sheet.dart';
import 'achievements_screen.dart';
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
  int _lastGain = 0;
  int _gainKey = 0;
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

  void _hint() {
    if (_gameOver || _config.mode == GameMode.daily) return;
    final direction = suggestMove(_engine.grid);
    if (direction == null) return;
    _noticeQueue
      ..clear()
      ..add('Hint: swipe ${direction.name}');
    _nextNotice();
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
      _lastGain = result.gained;
      _gainKey++;
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
      _lastGain = 0;
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
      _lastGain = 0;
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
    Navigator.of(context).push(softRoute<void>(const StatsScreen()));
  }

  void _openSettings() {
    Navigator.of(context).push(softRoute<void>(const SettingsScreen()));
  }

  void _openAchievements() {
    Navigator.of(context).push(softRoute<void>(const AchievementsScreen()));
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
    final timeColor = lowTime ? const Color(0xFFD6453D) : p.accentText;
    final topInset = MediaQuery.paddingOf(context).top;
    final glow = Color.lerp(p.background, Colors.white, p.isDark ? 0.07 : 0.6)!;

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1),
                radius: 1.15,
                colors: [glow, p.background],
                stops: const [0, 0.7],
              ),
            ),
            child: Stack(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: 'Pow',
                                children: [
                                  TextSpan(
                                    text: '2',
                                    style: TextStyle(color: p.accentText),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                color: p.text,
                              ),
                            ),
                            Row(
                              children: [
                                _RoundIconButton(
                                  palette: p,
                                  icon: Icons.emoji_events_rounded,
                                  label: 'Achievements',
                                  color: p.accentText,
                                  badge: _app.unlockedIds.length,
                                  onTap: _openAchievements,
                                ),
                                const SizedBox(width: 10),
                                _RoundIconButton(
                                  palette: p,
                                  icon: Icons.bar_chart_rounded,
                                  label: 'Stats',
                                  onTap: _openStats,
                                ),
                                const SizedBox(width: 10),
                                _RoundIconButton(
                                  palette: p,
                                  icon: Icons.settings_rounded,
                                  label: 'Settings',
                                  onTap: _openSettings,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ScoreCard(
                                palette: p,
                                label: 'SCORE',
                                value: _engine.score,
                                valueColor: p.text,
                                gain: _lastGain,
                                gainKey: _gainKey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ScoreCard(
                                palette: p,
                                label: isZen ? 'TILE' : 'BEST',
                                value: isZen
                                    ? _engine.highestTile
                                    : (isDaily
                                        ? _app.dailyBest(_dailyDay)
                                        : _app.bestFor(_config)),
                                valueColor: p.accentText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Semantics(
                              button: true,
                              label: 'Change mode and board size',
                              child: PressScale(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _openSetup,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: p.mutedText
                                              .withValues(alpha: 0.45),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _config.label,
                                            style: TextStyle(
                                              fontSize: 14,
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
                            ),
                            const Spacer(),
                            if (isTimed) ...[
                              Icon(
                                Icons.timer_outlined,
                                size: 20,
                                color: timeColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTime(_secondsLeft),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: timeColor,
                                ),
                              ),
                            ] else if (isDaily) ...[
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 22,
                                color: p.accentText,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${_app.dailyStreakNow}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: p.text,
                                ),
                              ),
                            ] else
                              Text.rich(
                                TextSpan(
                                  text: 'Biggest tile ',
                                  children: [
                                    TextSpan(
                                      text: '${_engine.highestTile}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: p.text,
                                      ),
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.mutedText,
                                ),
                              ),
                          ],
                        ),
                        if (isTimed) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                end: _secondsLeft / GameConfig.timedSeconds,
                              ),
                              duration: const Duration(seconds: 1),
                              curve: Curves.linear,
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                value: value,
                                minHeight: 6,
                                backgroundColor: p.emptyCell,
                                color: lowTime
                                    ? const Color(0xFFD6453D)
                                    : p.accent,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: ActionButton(
                                label: undoDepth > 0 && !isDaily
                                    ? 'Undo ($undoDepth)'
                                    : 'Undo',
                                icon: Icons.undo_rounded,
                                onPressed:
                                    _engine.canUndo && !isDaily ? _undo : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            PressScale(
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Tooltip(
                                  message: 'Hint',
                                  child: FilledButton(
                                    onPressed:
                                        _gameOver || isDaily ? null : _hint,
                                    style: FilledButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      elevation: 3,
                                      shadowColor: Color(
                                        p.isDark ? 0x66000000 : 0x42503C1E,
                                      ),
                                      backgroundColor: p.card,
                                      foregroundColor: p.accentText,
                                      disabledBackgroundColor:
                                          p.card.withValues(alpha: 0.5),
                                      disabledForegroundColor:
                                          p.mutedText.withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 24,
                                    ),
                                  ),
                                ),
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
                        const SizedBox(height: 8),
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
                Positioned(
                  top: topInset + 72,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    child: AnimatedSlide(
                      offset: _bannerVisible
                          ? Offset.zero
                          : const Offset(0, -1.8),
                      duration: const Duration(milliseconds: 450),
                      curve: _bannerVisible
                          ? Curves.easeOutBack
                          : Curves.easeIn,
                      child: AnimatedOpacity(
                        opacity: _bannerVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: _Banner(palette: p, text: _bannerText),
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
      ),
    );
  }
}

Color _shadowColor(Pow2Palette p) =>
    Color(p.isDark ? 0x55000000 : 0x1F503C1E);

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badge = 0,
  });

  final Pow2Palette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.card,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _shadowColor(palette),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Icon(
                    icon,
                    size: 22,
                    color: color ?? palette.mutedText,
                  ),
                ),
              ),
            ),
            if (badge > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.onAccent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.palette,
    required this.label,
    required this.value,
    required this.valueColor,
    this.gain = 0,
    this.gainKey = 0,
  });

  final Pow2Palette palette;
  final String label;
  final int value;
  final Color valueColor;

  /// Points of the last move. Shown for a moment as a floating "+n".
  final int gain;
  final int gainKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _shadowColor(palette),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: palette.mutedText,
                ),
              ),
              TweenAnimationBuilder<int>(
                tween: IntTween(end: value),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, shown, _) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatNumber(shown),
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (gain > 0)
            Positioned(
              right: 0,
              top: 0,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(gainKey),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (context, t, _) {
                  final opacity = t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85;
                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -26 * t),
                      child: Text(
                        '+$gain',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: palette.accentText,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// The message that drops from the top: milestones, hints and achievements.
class _Banner extends StatelessWidget {
  const _Banner({required this.palette, required this.text});

  final Pow2Palette palette;
  final String text;

  static const String _achievementPrefix = 'Achievement: ';

  @override
  Widget build(BuildContext context) {
    final isAchievement = text.startsWith(_achievementPrefix);
    final isHint = text.startsWith('Hint: ');
    final icon = isAchievement
        ? Icons.emoji_events_rounded
        : isHint
            ? Icons.lightbulb_outline_rounded
            : Icons.star_rounded;
    final light = Color.lerp(palette.accent, Colors.white, 0.4)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [palette.accent, light],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.onAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isAchievement
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ACHIEVEMENT UNLOCKED',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: palette.onAccent.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        text.substring(_achievementPrefix.length),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: palette.onAccent,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 17,
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
