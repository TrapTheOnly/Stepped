import 'package:flutter/material.dart';

import '../wishlist_credits_client.dart';
import 'wishlist_editor_shell.dart';

class WishlistPlanCreditsCard extends StatelessWidget {
  const WishlistPlanCreditsCard({
    super.key,
    required this.credits,
  });

  final WishlistCreditsSnapshot credits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final planName = credits.isPlus ? 'Plus' : 'Free';
    final resetLabel = credits.nextResetAt == null
        ? 'Reset date unavailable'
        : 'Resets on ${_formatDate(credits.nextResetAt!)}';

    return WishlistEditorSectionCard(
      title: '$planName credits',
      subtitle: resetLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.bolt_outlined,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${credits.remainingCredits}/${credits.monthlyLimit} generations left this month',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$planName plan',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: credits.usageProgress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 10),
          Text(
            'Daily burst: ${credits.dailyBurstLimit} · '
            'Rewarded ads left: ${credits.rewardedAdRemaining}/${credits.rewardedAdMonthlyLimit}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
