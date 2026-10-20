import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'press_scale.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.height = 56,
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      elevation: primary ? 6 : 0,
      shadowColor: p.accent.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: TextStyle(
        fontSize: 15,
        fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
      ),
    );

    if (icon == null) {
      return PressScale(
        child: FilledButton(
          onPressed: onPressed,
          style: style,
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      );
    }
    return PressScale(
      child: FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 20),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      ),
    );
  }
}
