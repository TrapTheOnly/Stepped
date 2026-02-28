import 'package:flutter/material.dart';

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
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.key_off_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        title: Text(
          usingCloudApi
              ? 'Cloud API URL is missing'
              : 'Gemini API key is missing',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        subtitle: Text(
          usingCloudApi
              ? 'Open Settings and add your Cloud backend URL to use AI planning.'
              : 'Open Settings and add your Gemini key to use AI planning.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        trailing: FilledButton(
          onPressed: onOpenSettings,
          child: const Text('Settings'),
        ),
      ),
    );
  }
}
