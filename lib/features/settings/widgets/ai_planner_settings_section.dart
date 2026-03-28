import 'package:flutter/material.dart';

import '../../../widgets/frosted_squircle.dart';
import '../settings_types.dart';
import 'settings_form_sections.dart';

class AiPlannerSettingsSection extends StatelessWidget {
  const AiPlannerSettingsSection({
    super.key,
    required this.colorScheme,
    required this.aiSourceChoice,
    required this.cloudApiBaseUrlController,
    required this.geminiApiKeyController,
    required this.showGeminiApiKey,
    required this.onAiSourceChanged,
    required this.onToggleGeminiApiKeyVisibility,
    required this.onClearGeminiApiKey,
  });

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
    return SettingsSectionShell(
      title: 'AI planner',
      child: SettingsEditorialCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _AiSourceChip(
                    label: 'Cloud API',
                    icon: Icons.cloud_outlined,
                    selected: aiSourceChoice == AiSourceChoice.cloud,
                    onTap: () => onAiSourceChanged(AiSourceChoice.cloud),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AiSourceChip(
                    label: 'Local key',
                    icon: Icons.key_outlined,
                    selected: aiSourceChoice == AiSourceChoice.local,
                    onTap: () => onAiSourceChanged(AiSourceChoice.local),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (aiSourceChoice == AiSourceChoice.cloud)
              _PlannerFieldCard(
                child: TextField(
                  controller: cloudApiBaseUrlController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Cloud backend base URL',
                    hintText: 'https://api.stepped.world',
                    prefixIcon: const Icon(Icons.link_outlined),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.34),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.16),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
              ),
            if (aiSourceChoice == AiSourceChoice.local) ...<Widget>[
              _PlannerFieldCard(
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
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.34),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.16),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ClearKeyButton(
                enabled: geminiApiKeyController.text.trim().isNotEmpty,
                onTap: onClearGeminiApiKey,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiSourceChip extends StatelessWidget {
  const _AiSourceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.pressed)
              ? colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: ShapeDecoration(
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.90)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.30),
            shape: squircleShape(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannerFieldCard extends StatelessWidget {
  const _PlannerFieldCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.20),
        shape: squircleShape(26),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: child,
      ),
    );
  }
}

class _ClearKeyButton extends StatelessWidget {
  const _ClearKeyButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.pressed)
              ? colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: enabled
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.28)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
            shape: squircleShape(22),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.delete_outline_rounded,
                  color: enabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Clear API key',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
