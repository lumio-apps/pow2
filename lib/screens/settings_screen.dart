import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../update_flow.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SectionTitle(text: 'Theme', palette: p),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < kPalettes.length; i++)
                  _ThemeCard(
                    palette: kPalettes[i],
                    current: p,
                    selected: i == app.themeIndex,
                    onTap: () => app.setTheme(i),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(text: 'Feedback', palette: p),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound'),
              subtitle: const Text('A soft click when tiles merge'),
              value: app.soundOn,
              onChanged: app.setSound,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibration'),
              subtitle: const Text('A light buzz on merges and milestones'),
              value: app.hapticsOn,
              onChanged: app.setHaptics,
            ),
            const SizedBox(height: 16),
            _SectionTitle(text: 'Storage', palette: p),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                app.storage.isPersistent
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
              ),
              title: const Text('Saving'),
              subtitle: Text(app.storage.statusText),
            ),
            if (!app.storage.isPersistent)
              Padding(
                padding: const EdgeInsets.only(left: 56, bottom: 8),
                child: SelectableText(
                  app.storage.debugText,
                  style: TextStyle(fontSize: 11, color: p.mutedText),
                ),
              ),
            const SizedBox(height: 16),
            _SectionTitle(text: 'About', palette: p),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Version'),
                  subtitle: Text(
                    info == null
                        ? '...'
                        : '${info.version} (build ${info.buildNumber})',
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.system_update_outlined),
              title: const Text('Check for updates'),
              subtitle: const Text('Looks for a new version on GitHub'),
              onTap: () => checkForUpdates(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Privacy'),
              subtitle: const Text(
                'Offline game. No ads, no tracking. Scores stay on your '
                'phone. Open source.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.palette});

  final String text;
  final Pow2Palette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: palette.mutedText,
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.palette,
    required this.current,
    required this.selected,
    required this.onTap,
  });

  /// The look this card shows.
  final Pow2Palette palette;

  /// The look the screen uses now (for the card's border).
  final Pow2Palette current;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color color) => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.name} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? current.accentText
                  : current.mutedText.withValues(alpha: 0.4),
              width: selected ? 3 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  swatch(palette.tiles[0].background),
                  const SizedBox(width: 6),
                  swatch(palette.tiles[3].background),
                  const SizedBox(width: 6),
                  swatch(palette.tiles[6].background),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      palette.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: palette.accentText,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
