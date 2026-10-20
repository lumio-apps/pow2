import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../game/game_engine.dart';
import 'tile_widget.dart';

/// The 4x4 board. Tiles are positioned with [AnimatedPositioned] so they slide.
class BoardView extends StatelessWidget {
  const BoardView({super.key, required this.tiles, required this.dying});

  final List<Tile> tiles;

  /// Tiles that were just merged away. They slide into place and then vanish.
  final List<Tile> dying;

  static const double _padding = 10;
  static const double _gap = 10;
  static const Duration _slide = Duration(milliseconds: 110);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final cell =
            (side - 2 * _padding - (GameEngine.size - 1) * _gap) / GameEngine.size;
        double offset(int index) => _padding + index * (cell + _gap);

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
                for (var r = 0; r < GameEngine.size; r++)
                  for (var c = 0; c < GameEngine.size; c++)
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
