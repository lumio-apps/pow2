import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../game/achievements.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = context.palette;
    final unlocked = app.unlockedIds;
    final done = kAchievements.where((a) => unlocked.contains(a.id)).length;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Achievements')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                '$done of ${kAchievements.length} unlocked',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.mutedText,
                ),
              ),
            ),
            for (final a in kAchievements)
              _AchievementTile(achievement: a, unlocked: unlocked.contains(a.id)),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '${achievement.title}. ${achievement.description}. '
          '${unlocked ? 'Unlocked' : 'Locked'}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: unlocked ? p.accent : p.emptyCell,
                shape: BoxShape.circle,
              ),
              child: Icon(
                unlocked ? achievement.icon : Icons.lock_outline_rounded,
                color: unlocked ? p.onAccent : p.mutedText,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: unlocked ? p.text : p.mutedText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: TextStyle(fontSize: 13, color: p.mutedText),
                  ),
                ],
              ),
            ),
            if (unlocked)
              Icon(Icons.check_circle_rounded, color: p.accentText),
          ],
        ),
      ),
    );
  }
}
