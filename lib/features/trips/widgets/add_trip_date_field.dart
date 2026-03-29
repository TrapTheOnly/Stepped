import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTripDateField extends StatelessWidget {
  const AddTripDateField({
    super.key,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.onTap,
  });

  final String label;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasRange = startDate != null && endDate != null;
    final monthDay = hasRange
        ? '${DateFormat('MMM d').format(startDate!)} - ${DateFormat('MMM d').format(endDate!)}'
        : 'Not set';
    final year = hasRange
        ? _yearAndDurationLabel(startDate!, endDate!)
        : 'Pick travel dates';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      monthDay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      year,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _yearAndDurationLabel(DateTime startDate, DateTime endDate) {
  final startYear = DateFormat('y').format(startDate);
  final endYear = DateFormat('y').format(endDate);
  final nights = endDate.difference(startDate).inDays;
  final tripDays = nights <= 0 ? 1 : nights + 1;
  final yearLabel =
      startYear == endYear ? startYear : '$startYear - $endYear';
  return '$yearLabel · $tripDays ${tripDays == 1 ? 'day' : 'days'}';
}
