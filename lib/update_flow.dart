import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'theme.dart';
import 'update_checker.dart';

/// The whole "Check for updates" flow: look on GitHub, ask, download, install.
Future<void> checkForUpdates(BuildContext context) async {
  final p = context.palette;
  _showBusy(context, p, 'Checking for updates…');

  UpdateInfo? update;
  try {
    update = await UpdateChecker.check();
  } catch (_) {
    if (!context.mounted) return;
    Navigator.pop(context);
    _snack(
      context,
      'Could not check for updates. Please check your internet connection.',
    );
    return;
  }

  if (!context.mounted) return;
  Navigator.pop(context);

  if (update == null) {
    _snack(context, 'Pow2 is up to date.');
    return;
  }

  final available = update;
  final install = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: p.dialog,
      title: const Text('Update available'),
      content: SingleChildScrollView(
        child: Text(
          'Version ${available.version} is ready.'
          '${available.notes.isEmpty ? '' : '\n\n${available.notes}'}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Later'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: p.onAccent,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Update'),
        ),
      ],
    ),
  );
  if (install != true || !context.mounted) return;

  final progress = ValueNotifier<double>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: p.dialog,
        title: const Text('Downloading update…'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, _) => LinearProgressIndicator(
            value: value > 0 ? value : null,
            color: p.accentText,
          ),
        ),
      ),
    ),
  );

  try {
    await UpdateChecker.downloadAndInstall(
      available,
      (value) => progress.value = value,
    );
    if (!context.mounted) return;
    Navigator.pop(context);
  } catch (_) {
    if (!context.mounted) return;
    Navigator.pop(context);
    _snack(context, 'The update failed. Please try again.');
  }
}

void _showBusy(BuildContext context, Pow2Palette p, String text) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: p.dialog,
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: p.accentText,
              ),
            ),
            const SizedBox(width: 20),
            Flexible(child: Text(text)),
          ],
        ),
      ),
    ),
  );
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
