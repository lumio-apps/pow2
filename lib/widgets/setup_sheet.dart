import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../game/game_config.dart';
import 'action_button.dart';

/// Bottom sheet where the player picks a mode and a board size, then starts
/// a new game. Pops with the chosen [GameConfig], or null when dismissed.
class SetupSheet extends StatefulWidget {
  const SetupSheet({super.key, required this.initial});

  final GameConfig initial;

  @override
  State<SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<SetupSheet> {
  late GameMode _mode = widget.initial.mode;
  late int _size = widget.initial.size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New game',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
            const SizedBox(height: 20),
            _Label(text: 'Mode', color: p.mutedText),
            for (final mode in GameMode.values) ...[
              _ModeTile(
                mode: mode,
                selected: mode == _mode,
                onTap: () => setState(() => _mode = mode),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            _Label(text: 'Board size', color: p.mutedText),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final size in GameConfig.sizes)
                  ChoiceChip(
                    label: Text('$size×$size'),
                    selected: size == _size,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _size = size),
                    backgroundColor: p.card,
                    selectedColor: p.accent,
                    side: BorderSide(
                      color: size == _size
                          ? p.accent
                          : p.mutedText.withValues(alpha: 0.4),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: size == _size ? p.onAccent : p.text,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ActionButton(
              label: 'Start new game',
              primary: true,
              height: 56,
              onPressed: () =>
                  Navigator.pop(context, GameConfig(_mode, _size)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '${modeLabel(mode)} mode',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? p.accentText
                    : p.mutedText.withValues(alpha: 0.4),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modeLabel(mode),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        modeHint(mode),
                        style: TextStyle(fontSize: 13, color: p.mutedText),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: p.accentText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
