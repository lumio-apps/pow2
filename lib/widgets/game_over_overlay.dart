import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../format.dart';
import 'action_button.dart';

/// Shown when no moves are left.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    this.title = 'No moves left',
    required this.score,
    required this.bestTile,
    required this.canUndo,
    required this.onNewGame,
    required this.onUndo,
  });

  final String title;
  final int score;
  final int bestTile;
  final bool canUndo;
  final VoidCallback onNewGame;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = p.tileStyle(bestTile);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: ColoredBox(
        color: p.background.withValues(alpha: 0.96),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 176,
                  height: 176,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$bestTile',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: style.foreground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score ${formatNumber(score)} · Best tile $bestTile',
                  style: TextStyle(fontSize: 15, color: p.mutedText),
                ),
                const SizedBox(height: 28),
                ActionButton(
                  label: 'New game',
                  primary: true,
                  height: 56,
                  onPressed: onNewGame,
                ),
                if (canUndo) ...[
                  const SizedBox(height: 12),
                  ActionButton(
                    label: 'Undo last move',
                    height: 56,
                    onPressed: onUndo,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
