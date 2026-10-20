import 'package:flutter/material.dart';

/// Plain dark colors for the very first frame and for error screens, before
/// the saved theme is known.
const Color kSplashBackground = Color(0xFF1B1B2F);
const Color kSplashText = Color(0xFFF3E9D2);

class TileStyle {
  const TileStyle(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// All colors of one look. The player picks one in Settings.
class Pow2Palette {
  const Pow2Palette({
    required this.name,
    required this.isDark,
    required this.background,
    required this.panel,
    required this.emptyCell,
    required this.text,
    required this.mutedText,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.tiles,
    required this.bigTile,
  });

  final String name;
  final bool isDark;
  final Color background;
  final Color panel;
  final Color emptyCell;
  final Color text;
  final Color mutedText;

  /// Fill color of the main buttons and the milestone banner.
  final Color accent;

  /// Text and icons on top of [accent].
  final Color onAccent;

  /// The accent when it is used as text color on [background].
  final Color accentText;

  /// Styles for 2, 4, 8 ... 2048, in this order.
  final List<TileStyle> tiles;

  /// Style for every tile above the last entry of [tiles].
  final TileStyle bigTile;

  /// Fill of the score boxes and the stats card. The muted and accent text
  /// colors are made to read well on it.
  Color get card => isDark ? panel : const Color(0xFFFFFFFF);

  /// Background of dialogs.
  Color get dialog => isDark ? panel : background;

  TileStyle tileStyle(int value) {
    var power = 0;
    var rest = value;
    while (rest > 1) {
      rest >>= 1;
      power++;
    }
    final index = power - 1;
    if (index < 0) return tiles.first;
    if (index >= tiles.length) return bigTile;
    return tiles[index];
  }
}

const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF2A2238);

const List<Pow2Palette> kPalettes = [
  Pow2Palette(
    name: 'Midnight',
    isDark: true,
    background: Color(0xFF1B1B2F),
    panel: Color(0xFF2B2B47),
    emptyCell: Color(0xFF36365A),
    text: Color(0xFFF3E9D2),
    mutedText: Color(0xFFB9B6D3),
    accent: Color(0xFFF2C230),
    onAccent: _ink,
    accentText: Color(0xFFF2C230),
    tiles: [
      TileStyle(Color(0xFFF3E9D2), _ink),
      TileStyle(Color(0xFFF0D9A8), _ink),
      TileStyle(Color(0xFFF5A55B), _ink),
      TileStyle(Color(0xFFF27C4B), _ink),
      TileStyle(Color(0xFFD6453D), _white),
      TileStyle(Color(0xFFB8336A), _white),
      TileStyle(Color(0xFF7A3FB0), _white),
      TileStyle(Color(0xFF4B4BC4), _white),
      TileStyle(Color(0xFF2D6FC2), _white),
      TileStyle(Color(0xFF187A6F), _white),
      TileStyle(Color(0xFFF2C230), _ink),
    ],
    bigTile: TileStyle(Color(0xFFFF7AA8), _ink),
  ),
  Pow2Palette(
    name: 'Daylight',
    isDark: false,
    background: Color(0xFFF4EFE6),
    panel: Color(0xFFBBAE98),
    emptyCell: Color(0xFFCDC1AB),
    text: _ink,
    mutedText: Color(0xFF6B6580),
    accent: Color(0xFFF2C230),
    onAccent: _ink,
    accentText: Color(0xFF8A5A00),
    tiles: [
      TileStyle(Color(0xFFFFFFFF), _ink),
      TileStyle(Color(0xFFF7E7C4), _ink),
      TileStyle(Color(0xFFF5A55B), _ink),
      TileStyle(Color(0xFFF27C4B), _ink),
      TileStyle(Color(0xFFD6453D), _white),
      TileStyle(Color(0xFFB8336A), _white),
      TileStyle(Color(0xFF7A3FB0), _white),
      TileStyle(Color(0xFF4B4BC4), _white),
      TileStyle(Color(0xFF2D6FC2), _white),
      TileStyle(Color(0xFF187A6F), _white),
      TileStyle(Color(0xFFF2C230), _ink),
    ],
    bigTile: TileStyle(Color(0xFFFF7AA8), _ink),
  ),
  Pow2Palette(
    name: 'Ocean',
    isDark: true,
    background: Color(0xFF0B1F33),
    panel: Color(0xFF14344F),
    emptyCell: Color(0xFF1B4666),
    text: Color(0xFFE6F4FA),
    mutedText: Color(0xFF9CC3D8),
    accent: Color(0xFF4DD0E1),
    onAccent: Color(0xFF06222E),
    accentText: Color(0xFF4DD0E1),
    tiles: [
      TileStyle(Color(0xFFE6F4FA), Color(0xFF06222E)),
      TileStyle(Color(0xFFBFE3F0), Color(0xFF06222E)),
      TileStyle(Color(0xFF7FD1E8), Color(0xFF06222E)),
      TileStyle(Color(0xFF3FB6DA), Color(0xFF06222E)),
      TileStyle(Color(0xFF2A8FC4), _white),
      TileStyle(Color(0xFF2468B0), _white),
      TileStyle(Color(0xFF4C4FB0), _white),
      TileStyle(Color(0xFF6B3FA8), _white),
      TileStyle(Color(0xFF9C3E9C), _white),
      TileStyle(Color(0xFFC23A7F), _white),
      TileStyle(Color(0xFF4DD0E1), Color(0xFF06222E)),
    ],
    bigTile: TileStyle(Color(0xFFFFB74D), Color(0xFF06222E)),
  ),
  Pow2Palette(
    name: 'Candy',
    isDark: false,
    background: Color(0xFFFFF0F5),
    panel: Color(0xFFF4C6D7),
    emptyCell: Color(0xFFF9DCE6),
    text: Color(0xFF4A2040),
    mutedText: Color(0xFF8A5A7A),
    accent: Color(0xFFFF6FA5),
    onAccent: Color(0xFF3B1030),
    accentText: Color(0xFFC2185B),
    tiles: [
      TileStyle(Color(0xFFFFFFFF), Color(0xFF4A2040)),
      TileStyle(Color(0xFFFFE0EC), Color(0xFF4A2040)),
      TileStyle(Color(0xFFFFB3CF), Color(0xFF4A2040)),
      TileStyle(Color(0xFFFF8FB8), Color(0xFF4A2040)),
      TileStyle(Color(0xFFFF6FA5), Color(0xFF3B1030)),
      TileStyle(Color(0xFFD9407F), _white),
      TileStyle(Color(0xFFB03A9E), _white),
      TileStyle(Color(0xFF8A3FB5), _white),
      TileStyle(Color(0xFF6A4CC4), _white),
      TileStyle(Color(0xFF4A5BC8), _white),
      TileStyle(Color(0xFFFFC107), Color(0xFF3B1030)),
    ],
    bigTile: TileStyle(Color(0xFF26A69A), _white),
  ),
];
