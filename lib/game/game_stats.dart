import 'dart:math';

/// Numbers shown on the Stats screen. They live only on the device.
class GameStats {
  const GameStats({
    this.gamesPlayed = 0,
    this.totalMoves = 0,
    this.highestTile = 0,
  });

  factory GameStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GameStats();
    int read(String key) {
      final value = json[key];
      return value is int && value >= 0 ? value : 0;
    }

    return GameStats(
      gamesPlayed: read('games'),
      totalMoves: read('moves'),
      highestTile: read('tile'),
    );
  }

  final int gamesPlayed;
  final int totalMoves;
  final int highestTile;

  GameStats withMove(int tile) => GameStats(
        gamesPlayed: gamesPlayed,
        totalMoves: totalMoves + 1,
        highestTile: max(highestTile, tile),
      );

  GameStats withGamesPlayed(int games) => GameStats(
        gamesPlayed: max(0, games),
        totalMoves: totalMoves,
        highestTile: highestTile,
      );

  Map<String, dynamic> toJson() => {
        'games': gamesPlayed,
        'moves': totalMoves,
        'tile': highestTile,
      };
}
