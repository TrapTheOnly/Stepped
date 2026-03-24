import 'package:flutter/material.dart';

import '../gemini_trip_models.dart';
import 'wishlist_editor_shell.dart';
import 'wishlist_plan_result_widgets.dart';

class WishlistPlanGenerationSection extends StatelessWidget {
  const WishlistPlanGenerationSection({
    super.key,
    required this.errorText,
    required this.plan,
    required this.generationCostCredits,
    required this.maxOutputTokens,
    this.onGenerate,
    this.isGenerating = false,
  });

  final String? errorText;
  final GeminiTripPlan? plan;
  final VoidCallback? onGenerate;
  final bool isGenerating;
  final int generationCostCredits;
  final int maxOutputTokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        WishlistEditorSectionCard(
          title: plan == null ? 'AI planning' : 'Current AI draft',
          subtitle:
              'Each generation costs $generationCostCredits credit${generationCostCredits == 1 ? '' : 's'}. Output stays capped at $maxOutputTokens tokens.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (isGenerating)
                Row(
                  children: <Widget>[
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Generating a refreshed route and city cards...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  plan == null
                      ? 'Once you generate, the itinerary preview will appear here before you head back to plan review.'
                      : 'You can regenerate to explore a different route while keeping your saved context.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (errorText != null) ...<Widget>[
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.92),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorText!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (onGenerate != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: onGenerate,
                              icon: const Icon(Icons.refresh_outlined),
                              label: const Text('Try again'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (plan != null) ...<Widget>[
          const SizedBox(height: 12),
          WishlistPlanResultCard(plan: plan!),
        ],
      ],
    );
  }
}
