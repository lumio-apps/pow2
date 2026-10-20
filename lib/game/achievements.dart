import 'package:flutter/material.dart';

import 'game_config.dart';

/// What the game knows when it checks for new achievements.
class AchievementContext {
  const AchievementContext({
    required this.allTimeTile,
    required this.gamesPlayed,
    required this.totalMoves,
    required this.score,
    required this.tile,
    required this.mode,
    required this.size,
    required this.dailyDays,
    required this.dailyStreak,
  });

  /// Biggest tile ever made.
  final int allTimeTile;
  final int gamesPlayed;
  final int totalMoves;

  /// Score and biggest tile of the game being played now.
  final int score;
  final int tile;
  final GameMode mode;
  final int size;

  /// How many different days the daily challenge was played.
  final int dailyDays;
  final int dailyStreak;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.test,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(AchievementContext) test;
}

final List<Achievement> kAchievements = [
  Achievement(
    id: 'tile128',
    title: 'Warm-up',
    description: 'Make a 128 tile',
    icon: Icons.local_fire_department_rounded,
    test: (c) => c.allTimeTile >= 128,
  ),
  Achievement(
    id: 'tile512',
    title: 'Getting serious',
    description: 'Make a 512 tile',
    icon: Icons.trending_up_rounded,
    test: (c) => c.allTimeTile >= 512,
  ),
  Achievement(
    id: 'tile1024',
    title: 'Big number',
    description: 'Make a 1024 tile',
    icon: Icons.bolt_rounded,
    test: (c) => c.allTimeTile >= 1024,
  ),
  Achievement(
    id: 'tile2048',
    title: 'Power of eleven',
    description: 'Make a 2048 tile',
    icon: Icons.workspace_premium_rounded,
    test: (c) => c.allTimeTile >= 2048,
  ),
  Achievement(
    id: 'tile4096',
    title: 'Beyond',
    description: 'Make a 4096 tile',
    icon: Icons.rocket_launch_rounded,
    test: (c) => c.allTimeTile >= 4096,
  ),
  Achievement(
    id: 'score5000',
    title: 'Five thousand',
    description: 'Score 5,000 in one game',
    icon: Icons.stars_rounded,
    test: (c) => c.score >= 5000,
  ),
  Achievement(
    id: 'score20000',
    title: 'Twenty thousand',
    description: 'Score 20,000 in one game',
    icon: Icons.emoji_events_rounded,
    test: (c) => c.score >= 20000,
  ),
  Achievement(
    id: 'games10',
    title: 'Regular',
    description: 'Finish 10 games',
    icon: Icons.replay_rounded,
    test: (c) => c.gamesPlayed >= 10,
  ),
  Achievement(
    id: 'games50',
    title: 'Dedicated',
    description: 'Finish 50 games',
    icon: Icons.favorite_rounded,
    test: (c) => c.gamesPlayed >= 50,
  ),
  Achievement(
    id: 'moves1000',
    title: 'Thousand swipes',
    description: 'Make 1,000 moves in total',
    icon: Icons.swipe_rounded,
    test: (c) => c.totalMoves >= 1000,
  ),
  Achievement(
    id: 'timed500',
    title: 'Beat the clock',
    description: 'Score 500 in Timed mode',
    icon: Icons.timer_rounded,
    test: (c) => c.mode == GameMode.timed && c.score >= 500,
  ),
  Achievement(
    id: 'zen512',
    title: 'Calm mind',
    description: 'Make a 512 tile in Zen mode',
    icon: Icons.spa_rounded,
    test: (c) => c.mode == GameMode.zen && c.tile >= 512,
  ),
  Achievement(
    id: 'big512',
    title: 'Big board',
    description: 'Make a 512 tile on a 6×6 board',
    icon: Icons.grid_view_rounded,
    test: (c) => c.size == 6 && c.tile >= 512,
  ),
  Achievement(
    id: 'tiny128',
    title: 'Tiny but mighty',
    description: 'Make a 128 tile on a 3×3 board',
    icon: Icons.crop_square_rounded,
    test: (c) => c.size == 3 && c.tile >= 128,
  ),
  Achievement(
    id: 'daily1',
    title: 'Daily player',
    description: 'Play the daily challenge',
    icon: Icons.today_rounded,
    test: (c) => c.dailyDays >= 1,
  ),
  Achievement(
    id: 'streak3',
    title: 'Three in a row',
    description: 'Play the daily challenge 3 days in a row',
    icon: Icons.event_repeat_rounded,
    test: (c) => c.dailyStreak >= 3,
  ),
  Achievement(
    id: 'streak7',
    title: 'Week streak',
    description: 'Play the daily challenge 7 days in a row',
    icon: Icons.date_range_rounded,
    test: (c) => c.dailyStreak >= 7,
  ),
];

/// Achievements whose rule is true now and that are not unlocked yet.
List<Achievement> newlyEarned(AchievementContext context, Set<String> have) => [
      for (final a in kAchievements)
        if (!have.contains(a.id) && a.test(context)) a,
    ];
