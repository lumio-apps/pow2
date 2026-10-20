import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../format.dart';
import '../game/game_config.dart';
import '../widgets/action_button.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final app = context.app;
    final p = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.dialog,
        title: const Text('Reset stats?'),
        content: const Text(
          'This clears all best scores and all statistics. '
          'It can not be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) app.resetStats();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = context.palette;
    final stats = app.stats;
    final bestTile = stats.highestTile;

    // Classic 4x4 is always listed. Other kinds appear once they have a score.
    final scored = [
      for (final config in GameConfig.scored)
        if ((config.mode == GameMode.classic && config.size == 4) ||
            app.bestFor(config) > 0)
          config,
    ];

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Stats')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  for (final config in scored)
                    _StatRow(
                      label: 'Best · ${config.label}',
                      value: formatNumber(app.bestFor(config)),
                      highlight: true,
                    ),
                  _StatRow(
                    label: 'Biggest tile',
                    value: bestTile == 0 ? '-' : '$bestTile',
                  ),
                  _StatRow(
                    label: 'Games played',
                    value: formatNumber(stats.gamesPlayed),
                  ),
                  _StatRow(
                    label: 'Total moves',
                    value: formatNumber(stats.totalMoves),
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stats are saved only on this phone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.mutedText),
            ),
            const SizedBox(height: 24),
            ActionButton(
              label: 'Reset stats',
              icon: Icons.delete_outline_rounded,
              onPressed: () => _confirmReset(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.last = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: p.mutedText.withValues(alpha: 0.25)),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: p.mutedText),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: highlight ? p.accentText : p.text,
            ),
          ),
        ],
      ),
    );
  }
}
