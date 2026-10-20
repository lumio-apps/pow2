import 'package:flutter/material.dart';

class Pow2Colors {
  const Pow2Colors._();

  static const Color background = Color(0xFF1B1B2F);
  static const Color panel = Color(0xFF2B2B47);
  static const Color emptyCell = Color(0xFF36365A);
  static const Color text = Color(0xFFF3E9D2);
  static const Color mutedText = Color(0xFFB9B6D3);
  static const Color gold = Color(0xFFF2C230);
  static const Color dark = Color(0xFF2A2238);
}

class TileStyle {
  const TileStyle(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

const Color _white = Color(0xFFFFFFFF);

TileStyle tileStyleFor(int value) {
  switch (value) {
    case 2:
      return const TileStyle(Color(0xFFF3E9D2), Pow2Colors.dark);
    case 4:
      return const TileStyle(Color(0xFFF0D9A8), Pow2Colors.dark);
    case 8:
      return const TileStyle(Color(0xFFF5A55B), Pow2Colors.dark);
    case 16:
      return const TileStyle(Color(0xFFF27C4B), Pow2Colors.dark);
    case 32:
      return const TileStyle(Color(0xFFD6453D), _white);
    case 64:
      return const TileStyle(Color(0xFFB8336A), _white);
    case 128:
      return const TileStyle(Color(0xFF7A3FB0), _white);
    case 256:
      return const TileStyle(Color(0xFF4B4BC4), _white);
    case 512:
      return const TileStyle(Color(0xFF2D6FC2), _white);
    case 1024:
      return const TileStyle(Color(0xFF187A6F), _white);
    case 2048:
      return const TileStyle(Pow2Colors.gold, Pow2Colors.dark);
    default:
      return const TileStyle(Color(0xFFFF7AA8), Pow2Colors.dark);
  }
}
