import 'dart:math';

import 'game_engine.dart' show Direction;

/// Slides one row to the left. Returns the new row and the score it gives.
(List<int>, int) _slideLine(List<int> line) {
  final values = line.where((v) => v != 0).toList();
  final out = <int>[];
  var gained = 0;
  var i = 0;
  while (i < values.length) {
    if (i + 1 < values.length && values[i] == values[i + 1]) {
      out.add(values[i] * 2);
      gained += values[i] * 2;
      i += 2;
    } else {
      out.add(values[i]);
      i++;
    }
  }
  while (out.length < line.length) {
    out.add(0);
  }
  return (out, gained);
}

class _Moved {
  const _Moved(this.grid, this.gained);

  final List<List<int>> grid;
  final int gained;
}

_Moved? _apply(List<List<int>> grid, Direction direction) {
  final n = grid.length;
  final next = List.generate(n, (_) => List.filled(n, 0));
  var gained = 0;
  for (var i = 0; i < n; i++) {
    // Read line i in the direction of the swipe, slide it, write it back.
    final line = <int>[
      for (var j = 0; j < n; j++)
        switch (direction) {
          Direction.left => grid[i][j],
          Direction.right => grid[i][n - 1 - j],
          Direction.up => grid[j][i],
          Direction.down => grid[n - 1 - j][i],
        },
    ];
    final (slid, points) = _slideLine(line);
    gained += points;
    for (var j = 0; j < n; j++) {
      switch (direction) {
        case Direction.left:
          next[i][j] = slid[j];
        case Direction.right:
          next[i][n - 1 - j] = slid[j];
        case Direction.up:
          next[j][i] = slid[j];
        case Direction.down:
          next[n - 1 - j][i] = slid[j];
      }
    }
  }
  var changed = false;
  for (var r = 0; r < n && !changed; r++) {
    for (var c = 0; c < n; c++) {
      if (next[r][c] != grid[r][c]) {
        changed = true;
        break;
      }
    }
  }
  return changed ? _Moved(next, gained) : null;
}

/// The board after a swipe (before a new tile appears), or null when the
/// swipe changes nothing.
List<List<int>>? applyMove(List<List<int>> grid, Direction direction) =>
    _apply(grid, direction)?.grid;

double _evaluate(List<List<int>> grid, int gained) {
  final n = grid.length;
  var empty = 0;
  var biggest = 0;
  var smooth = 0.0;
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      final v = grid[r][c];
      if (v == 0) {
        empty++;
        continue;
      }
      biggest = max(biggest, v);
      final e = log(v) / ln2;
      if (c + 1 < n && grid[r][c + 1] != 0) {
        smooth += (e - log(grid[r][c + 1]) / ln2).abs();
      }
      if (r + 1 < n && grid[r + 1][c] != 0) {
        smooth += (e - log(grid[r + 1][c]) / ln2).abs();
      }
    }
  }
  final corners = [
    grid[0][0],
    grid[0][n - 1],
    grid[n - 1][0],
    grid[n - 1][n - 1],
  ];
  final cornerBonus = corners.contains(biggest) ? 6.0 : 0.0;
  return empty * 3.0 + cornerBonus - smooth * 0.8 + log(gained + 1);
}

/// A good next swipe for [grid], or null when no swipe is possible.
/// It looks two swipes ahead and prefers free space, merges and a big tile
/// kept in a corner.
Direction? suggestMove(List<List<int>> grid) {
  Direction? best;
  var bestValue = double.negativeInfinity;
  for (final first in Direction.values) {
    final a = _apply(grid, first);
    if (a == null) continue;
    var value = _evaluate(a.grid, a.gained);
    var follow = double.negativeInfinity;
    for (final second in Direction.values) {
      final b = _apply(a.grid, second);
      if (b == null) continue;
      follow = max(follow, _evaluate(b.grid, b.gained));
    }
    if (follow != double.negativeInfinity) value += 0.5 * follow;
    if (value > bestValue) {
      bestValue = value;
      best = first;
    }
  }
  return best;
}
