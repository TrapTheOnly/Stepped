import 'package:flutter/material.dart';

import '../gemini_trip_models.dart';
import 'wishlist_plan_result_widgets.dart';

class WishlistPlanGenerationSection extends StatelessWidget {
  const WishlistPlanGenerationSection({
    super.key,
    required this.canGenerate,
    required this.isGenerating,
    required this.errorText,
    required this.plan,
    required this.onGenerate,
    required this.generationCostCredits,
    required this.maxOutputTokens,
  });

  final bool canGenerate;
  final bool isGenerating;
  final String? errorText;
  final GeminiTripPlan? plan;
  final VoidCallback onGenerate;
  final int generationCostCredits;
  final int maxOutputTokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.toll_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Costs $generationCostCredits AI credit per generation. '
                    'Response output is capped at $maxOutputTokens tokens.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: canGenerate ? onGenerate : null,
          icon: isGenerating
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_outlined),
          label: Text(isGenerating ? 'Generating...' : 'Generate AI Plan'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (errorText != null) ...<Widget>[
          const SizedBox(height: 10),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: canGenerate ? onGenerate : null,
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Try again'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (plan != null) ...<Widget>[
          const SizedBox(height: 12),
          WishlistPlanResultCard(plan: plan!),
        ],
      ],
    );
  }
}
