import 'package:flutter/material.dart';

import '../settings_section.dart';
import '../settings_types.dart';

class AiPlannerSettingsSection extends StatelessWidget {
  const AiPlannerSettingsSection({
    super.key,
    required this.textTheme,
    required this.colorScheme,
    required this.aiSourceChoice,
    required this.cloudApiBaseUrlController,
    required this.geminiApiKeyController,
    required this.showGeminiApiKey,
    required this.onAiSourceChanged,
    required this.onToggleGeminiApiKeyVisibility,
    required this.onClearGeminiApiKey,
  });

  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final AiSourceChoice aiSourceChoice;
  final TextEditingController cloudApiBaseUrlController;
  final TextEditingController geminiApiKeyController;
  final bool showGeminiApiKey;
  final ValueChanged<AiSourceChoice> onAiSourceChanged;
  final VoidCallback onToggleGeminiApiKeyVisibility;
  final VoidCallback onClearGeminiApiKey;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'AI Trip Planner',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'AI source',
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              SegmentedButton<AiSourceChoice>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<AiSourceChoice>>[
                  ButtonSegment<AiSourceChoice>(
                    value: AiSourceChoice.cloud,
                    icon: Icon(Icons.cloud_outlined),
                    label: Text('Cloud API'),
                  ),
                  ButtonSegment<AiSourceChoice>(
                    value: AiSourceChoice.local,
                    icon: Icon(Icons.key_outlined),
                    label: Text('Local key'),
                  ),
                ],
                selected: <AiSourceChoice>{aiSourceChoice},
                onSelectionChanged: (selected) {
                  if (selected.isEmpty) {
                    return;
                  }
                  onAiSourceChanged(selected.first);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (aiSourceChoice == AiSourceChoice.cloud) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              controller: cloudApiBaseUrlController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Cloud backend base URL',
                hintText: 'https://api.stepped.world',
                prefixIcon: Icon(Icons.link_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'The app sends planning requests to your cloud backend. No Gemini key is required on device.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (aiSourceChoice == AiSourceChoice.local) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              controller: geminiApiKeyController,
              obscureText: !showGeminiApiKey,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Gemini API key',
                hintText: 'Paste your Gemini API token',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  tooltip: showGeminiApiKey ? 'Hide key' : 'Show key',
                  onPressed: onToggleGeminiApiKeyVisibility,
                  icon: Icon(
                    showGeminiApiKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Used only for wishlist AI planning requests from this device.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear API key'),
            subtitle: const Text('Remove the stored Gemini token.'),
            enabled: geminiApiKeyController.text.trim().isNotEmpty,
            onTap: geminiApiKeyController.text.trim().isEmpty
                ? null
                : onClearGeminiApiKey,
          ),
        ],
      ],
    );
  }
}
