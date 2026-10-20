import 'package:flutter/material.dart';

import '../app_controller.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = FilledButton.styleFrom(
      minimumSize: Size.fromHeight(height),
      backgroundColor: primary ? p.accent : p.panel,
      foregroundColor: primary ? p.onAccent : p.text,
      disabledBackgroundColor: p.panel.withValues(alpha: 0.5),
      disabledForegroundColor: p.mutedText.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: TextStyle(
        fontSize: 15,
        fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
      ),
    );

    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}
