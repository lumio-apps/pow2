enum GameMode { classic, timed, zen }

/// Which kind of game is played: a mode and a board size.
class GameConfig {
  const GameConfig(this.mode, this.size);

  static const List<int> sizes = [3, 4, 5, 6];

  /// Length of a Timed game.
  static const int timedSeconds = 180;

  static const GameConfig standard = GameConfig(GameMode.classic, 4);

  final GameMode mode;
  final int size;

  /// Storage key of the best score for this kind of game, or null when the
  /// mode keeps no best score (Zen).
  /// Classic 4x4 keeps the key of the first versions, so old best scores stay.
  String? get bestKey {
    if (mode == GameMode.zen) return null;
    if (mode == GameMode.classic && size == 4) return 'best_score';
    return 'best_${mode.name}_$size';
  }

  String get label => '${modeLabel(mode)} · $size×$size';

  /// Every kind of game that has its own best score.
  static List<GameConfig> get scored => [
        for (final mode in [GameMode.classic, GameMode.timed])
          for (final size in sizes) GameConfig(mode, size),
      ];

  static GameMode modeFromName(String? name) => GameMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => GameMode.classic,
      );

  static int safeSize(int size) => sizes.contains(size) ? size : 4;
}

String modeLabel(GameMode mode) {
  switch (mode) {
    case GameMode.classic:
      return 'Classic';
    case GameMode.timed:
      return 'Timed';
    case GameMode.zen:
      return 'Zen';
  }
}

String modeHint(GameMode mode) {
  switch (mode) {
    case GameMode.classic:
      return 'Play until no moves are left.';
    case GameMode.timed:
      return '3 minutes. The clock starts with your first move.';
    case GameMode.zen:
      return 'No game over. When the board is full, the smallest tiles '
          'are cleared. No best score.';
  }
}
