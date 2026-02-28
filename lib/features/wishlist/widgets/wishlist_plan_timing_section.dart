import 'package:flutter/material.dart';

import '../gemini_trip_models.dart';
import '../wishlist_plan_form_types.dart';

class WishlistPlanTimingSection extends StatelessWidget {
  const WishlistPlanTimingSection({
    super.key,
    required this.timeInputMode,
    required this.dateRange,
    required this.selectedMonth,
    required this.selectedDurationPreference,
    required this.onTimeInputModeChanged,
    required this.onPickDateRange,
    required this.onMonthChanged,
    required this.onDurationPreferenceChanged,
    required this.formatDate,
  });

  final WishlistTimeInputMode timeInputMode;
  final DateTimeRange? dateRange;
  final int? selectedMonth;
  final GeminiDurationPreference? selectedDurationPreference;
  final ValueChanged<WishlistTimeInputMode> onTimeInputModeChanged;
  final VoidCallback onPickDateRange;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<GeminiDurationPreference?> onDurationPreferenceChanged;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '2) Travel timing and stay duration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SegmentedButton<WishlistTimeInputMode>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<WishlistTimeInputMode>>[
                ButtonSegment<WishlistTimeInputMode>(
                  value: WishlistTimeInputMode.aiRecommended,
                  icon: Icon(Icons.auto_awesome_outlined),
                  label: Text('AI decides'),
                ),
                ButtonSegment<WishlistTimeInputMode>(
                  value: WishlistTimeInputMode.preciseDates,
                  icon: Icon(Icons.date_range_outlined),
                  label: Text('Precise dates'),
                ),
                ButtonSegment<WishlistTimeInputMode>(
                  value: WishlistTimeInputMode.monthAndDuration,
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('Month + duration'),
                ),
              ],
              selected: <WishlistTimeInputMode>{timeInputMode},
              onSelectionChanged: (selected) {
                if (selected.isEmpty) {
                  return;
                }
                onTimeInputModeChanged(selected.first);
              },
            ),
            if (timeInputMode ==
                WishlistTimeInputMode.preciseDates) ...<Widget>[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_outlined),
                title: Text(
                  dateRange == null
                      ? 'Pick a date range'
                      : '${formatDate(dateRange!.start)} - ${formatDate(dateRange!.end)}',
                ),
                trailing: TextButton(
                  onPressed: onPickDateRange,
                  child: Text(dateRange == null ? 'Select' : 'Change'),
                ),
              ),
            ],
            if (timeInputMode ==
                WishlistTimeInputMode.monthAndDuration) ...<Widget>[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'Preferred month',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                items: <DropdownMenuItem<int>>[
                  for (var month = 1; month <= DateTime.december; month += 1)
                    DropdownMenuItem<int>(
                      value: month,
                      child: Text(_monthName(month)),
                    ),
                ],
                onChanged: onMonthChanged,
              ),
              const SizedBox(height: 10),
              Text(
                'Choose your trip duration',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final option in geminiDurationPreferences)
                    ChoiceChip(
                      label: Text(
                        '${option.label} (${option.minDays}-${option.maxDays}d)',
                      ),
                      selected: selectedDurationPreference?.id == option.id,
                      onSelected: (selected) {
                        onDurationPreferenceChanged(selected ? option : null);
                      },
                    ),
                ],
              ),
            ],
            if (timeInputMode == WishlistTimeInputMode.aiRecommended)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'AI will recommend a practical travel month and duration.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _monthName(int month) {
  const names = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}
