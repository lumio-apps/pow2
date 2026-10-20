import 'dart:math';

import 'package:flutter/foundation.dart';

enum Direction { up, down, left, right }

/// A single tile on the board. Tiles keep their [id] while they slide so the
/// UI can animate them from the old position to the new one.
class Tile {
  Tile({
    required this.id,
    required this.value,
    required this.row,
    required this.col,
    this.isNew = false,
    this.merged = false,
  });

  factory Tile.fromJson(Map<String, dynamic> json) => Tile(
        id: json['id'] as int,
        value: json['v'] as int,
        row: json['r'] as int,
        col: json['c'] as int,
      );

  final int id;
  int value;
  int row;
  int col;

  /// True only for a tile spawned by the last move (used for the spawn animation).
  bool isNew;

  /// True while a tile has already merged during the current move.
  bool merged;

  Tile copy() => Tile(id: id, value: value, row: row, col: col);

  Map<String, dynamic> toJson() => {'id': id, 'v': value, 'r': row, 'c': col};
}

class MoveResult {
  const MoveResult({
    required this.moved,
    this.removed = const [],
    this.gained = 0,
  });

  final bool moved;

  /// Tiles that were merged into another tile. They slide to the merge
  /// position and are then dropped by the UI.
  final List<Tile> removed;

  final int gained;
}

class _Snapshot {
  _Snapshot(this.tiles, this.score, this.nextId, this.celebrated);

  final List<Tile> tiles;
  final int score;
  final int nextId;
  final int celebrated;
}

/// Pure game logic. No Flutter widgets in here, so it is easy to test.
class GameEngine {
  GameEngine({this.size = 4, Random? random}) : _random = random ?? Random();

  /// How many moves can be taken back, one after the other.
  static const int maxUndo = 3;

  /// Tile values that trigger a short congratulation message, once per game.
  static const List<int> milestones = [256, 512, 1024, 2048, 4096, 8192];

  /// Number of rows and columns.
  final int size;

  final Random _random;

  List<Tile> tiles = [];
  int score = 0;

  /// Highest milestone that has already been celebrated in this game.
  int celebrated = 0;

  int _nextId = 1;
  final List<_Snapshot> _undoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;

  /// How many moves can be taken back right now (0 to [maxUndo]).
  int get undoDepth => _undoStack.length;

  int get highestTile => tiles.fold<int>(0, (m, t) => max(m, t.value));

  List<List<int>> get grid {
    final values = List.generate(size, (_) => List.filled(size, 0));
    for (final tile in tiles) {
      values[tile.row][tile.col] = tile.value;
    }
    return values;
  }

  bool get isGameOver {
    if (tiles.length < size * size) return false;
    final values = grid;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = values[r][c];
        if (c + 1 < size && values[r][c + 1] == v) return false;
        if (r + 1 < size && values[r + 1][c] == v) return false;
      }
    }
    return true;
  }

  void reset() {
    tiles = [];
    score = 0;
    celebrated = 0;
    _undoStack.clear();
    _spawn();
    _spawn();
  }

  MoveResult move(Direction direction, {bool spawnTile = true}) {
    final snapshot = _Snapshot(
      tiles.map((t) => t.copy()).toList(),
      score,
      _nextId,
      celebrated,
    );

    for (final tile in tiles) {
      tile.isNew = false;
      tile.merged = false;
    }

    final removed = <Tile>[];
    var moved = false;
    var gained = 0;

    for (var line = 0; line < size; line++) {
      final inLine = _lineTiles(direction, line);
      var slot = 0;
      Tile? last;
      for (final tile in inLine) {
        final fromRow = tile.row;
        final fromCol = tile.col;
        if (last != null && !last.merged && last.value == tile.value) {
          last.value *= 2;
          last.merged = true;
          gained += last.value;
          tile.row = last.row;
          tile.col = last.col;
          removed.add(tile);
          moved = true;
        } else {
          _place(tile, direction, line, slot);
          slot++;
          last = tile;
          if (tile.row != fromRow || tile.col != fromCol) moved = true;
        }
      }
    }

    if (!moved) return const MoveResult(moved: false);

    tiles.removeWhere(removed.contains);
    score += gained;
    _undoStack.add(snapshot);
    if (_undoStack.length > maxUndo) _undoStack.removeAt(0);
    if (spawnTile) _spawn();
    return MoveResult(moved: true, removed: removed, gained: gained);
  }

  /// Takes back the last move. Up to [maxUndo] moves can be taken back.
  bool undo() {
    if (_undoStack.isEmpty) return false;
    final snapshot = _undoStack.removeLast();
    tiles = snapshot.tiles;
    score = snapshot.score;
    _nextId = snapshot.nextId;
    celebrated = snapshot.celebrated;
    return true;
  }

  /// Removes every tile that has the smallest value on the board. Zen mode
  /// uses this when the board is full, so the game never ends.
  /// Returns how many tiles were removed.
  int clearSmallest() {
    if (tiles.isEmpty) return 0;
    final smallest = tiles.map((t) => t.value).reduce(min);
    final before = tiles.length;
    tiles.removeWhere((t) => t.value == smallest);
    return before - tiles.length;
  }

  /// Returns the highest milestone newly reached, or null. Call once per move.
  int? takeMilestone() {
    final best = highestTile;
    int? reached;
    for (final milestone in milestones) {
      if (best >= milestone && milestone > celebrated) reached = milestone;
    }
    if (reached != null) celebrated = reached;
    return reached;
  }

  Map<String, dynamic> toJson() => {
        'size': size,
        'tiles': tiles.map((t) => t.toJson()).toList(),
        'score': score,
        'nextId': _nextId,
        'celebrated': celebrated,
      };

  /// Loads a saved game. Returns false (and changes nothing) if the data is
  /// invalid or was saved for a different board size.
  bool restore(Map<String, dynamic> json) {
    try {
      final savedSize = (json['size'] as int?) ?? 4;
      if (savedSize != size) return false;
      final loaded = (json['tiles'] as List)
          .map((e) => Tile.fromJson(e as Map<String, dynamic>))
          .toList();
      if (loaded.isEmpty) return false;
      final cells = <int>{};
      for (final tile in loaded) {
        final inBounds =
            tile.row >= 0 && tile.row < size && tile.col >= 0 && tile.col < size;
        if (!inBounds || tile.value < 2 || !cells.add(tile.row * size + tile.col)) {
          return false;
        }
      }
      final savedScore = json['score'] as int;
      final savedNextId = json['nextId'] as int;
      final savedCelebrated = (json['celebrated'] as int?) ?? 0;
      final maxId = loaded.fold<int>(0, (m, t) => max(m, t.id));

      tiles = loaded;
      score = savedScore;
      _nextId = max(savedNextId, maxId + 1);
      celebrated = savedCelebrated;
      _undoStack.clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  void loadValues(List<List<int>> values) {
    tiles = [];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (values[r][c] != 0) {
          tiles.add(Tile(id: _nextId++, value: values[r][c], row: r, col: c));
        }
      }
    }
    score = 0;
    celebrated = 0;
    _undoStack.clear();
  }

  /// Tiles of one row or column, ordered from the edge they move towards.
  List<Tile> _lineTiles(Direction direction, int line) {
    final horizontal = direction == Direction.left || direction == Direction.right;
    final inLine =
        tiles.where((t) => horizontal ? t.row == line : t.col == line).toList();
    switch (direction) {
      case Direction.left:
        inLine.sort((a, b) => a.col.compareTo(b.col));
      case Direction.right:
        inLine.sort((a, b) => b.col.compareTo(a.col));
      case Direction.up:
        inLine.sort((a, b) => a.row.compareTo(b.row));
      case Direction.down:
        inLine.sort((a, b) => b.row.compareTo(a.row));
    }
    return inLine;
  }

  void _place(Tile tile, Direction direction, int line, int slot) {
    switch (direction) {
      case Direction.left:
        tile.row = line;
        tile.col = slot;
      case Direction.right:
        tile.row = line;
        tile.col = size - 1 - slot;
      case Direction.up:
        tile.col = line;
        tile.row = slot;
      case Direction.down:
        tile.col = line;
        tile.row = size - 1 - slot;
    }
  }

  void _spawn() {
    final occupied = {for (final t in tiles) t.row * size + t.col};
    final empty = [
      for (var i = 0; i < size * size; i++)
        if (!occupied.contains(i)) i,
    ];
    if (empty.isEmpty) return;
    final cell = empty[_random.nextInt(empty.length)];
    tiles.add(
      Tile(
        id: _nextId++,
        value: _random.nextInt(10) == 0 ? 4 : 2,
        row: cell ~/ size,
        col: cell % size,
        isNew: true,
      ),
    );
  }
}
