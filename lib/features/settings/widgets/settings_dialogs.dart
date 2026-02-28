import 'package:flutter/material.dart';

Future<bool> showResetSettingsDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Reset settings?'),
            content: const Text(
              'This will restore default theme and profile preferences.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Reset'),
              ),
            ],
          );
        },
      ) ??
      false;
}
