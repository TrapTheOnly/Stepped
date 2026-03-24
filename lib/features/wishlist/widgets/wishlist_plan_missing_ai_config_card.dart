import 'package:flutter/material.dart';

import 'wishlist_editor_shell.dart';

class WishlistPlanMissingAiConfigCard extends StatelessWidget {
  const WishlistPlanMissingAiConfigCard({
    super.key,
    required this.usingCloudApi,
    required this.onOpenSettings,
  });

  final bool usingCloudApi;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return WishlistEditorSectionCard(
      title: usingCloudApi
          ? 'Cloud planner is not configured'
          : 'Gemini is not configured',
      subtitle: usingCloudApi
          ? 'Add your Cloud backend URL in Settings so AI planning can generate and charge credits correctly.'
          : 'Add your Gemini key in Settings to generate plans on-device.',
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Open Settings'),
        ),
      ),
    );
  }
}
