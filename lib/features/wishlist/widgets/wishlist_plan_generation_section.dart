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
          title: plan == null ? 'Generate route' : 'Refresh route',
          subtitle: plan == null
              ? 'AI will turn the trip idea above into city cards and a route draft.'
              : 'Generate again if you want a different route draft.',
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
                        'Building a fresh route draft...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  plan == null
                      ? 'Your city cards will appear here after generation.'
                      : 'The route cards below are ready to review.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
        if (errorText != null) ...<Widget>[
          const SizedBox(height: 12),
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
                        color:
                            Theme.of(context).colorScheme.onErrorContainer,
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
        if (plan != null) ...<Widget>[
          const SizedBox(height: 12),
          WishlistPlanResultCard(plan: plan!),
        ],
      ],
    );
  }
}
