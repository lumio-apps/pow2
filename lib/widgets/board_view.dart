import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../game/game_engine.dart';
import 'tile_widget.dart';

/// The board. Tiles are positioned with [AnimatedPositioned] so they slide.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.size,
    required this.tiles,
    required this.dying,
  });

  /// Number of rows and columns.
  final int size;

  final List<Tile> tiles;

  /// Tiles that were just merged away. They slide into place and then vanish.
  final List<Tile> dying;

  static const Duration _slide = Duration(milliseconds: 110);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Bigger boards use thinner gaps so the tiles stay readable.
    final gap = size >= 5 ? 6.0 : 10.0;
    final padding = gap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final cell = (side - 2 * padding - (size - 1) * gap) / size;
        double offset(int index) => padding + index * (cell + gap);

        Widget tileWidget(Tile tile) => AnimatedPositioned(
              key: ValueKey(tile.id),
              duration: _slide,
              curve: Curves.easeOut,
              left: offset(tile.col),
              top: offset(tile.row),
              width: cell,
              height: cell,
              child: TileWidget(
                value: tile.value,
                isNew: tile.isNew,
                size: cell,
              ),
            );

        return SizedBox.square(
          dimension: side,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                for (var r = 0; r < size; r++)
                  for (var c = 0; c < size; c++)
                    Positioned(
                      left: offset(c),
                      top: offset(r),
                      width: cell,
                      height: cell,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.emptyCell,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                for (final tile in dying) tileWidget(tile),
                for (final tile in tiles) tileWidget(tile),
              ],
            ),
          ),
        );
      },
    );
  }
}
