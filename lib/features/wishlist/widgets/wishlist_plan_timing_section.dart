import 'package:flutter/material.dart';

import '../../../widgets/frosted_squircle.dart';
import '../gemini_trip_models.dart';
import '../wishlist_plan_form_types.dart';
import 'wishlist_editor_shell.dart';

const _clearMonthSelection = -1;

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
    return WishlistEditorSectionCard(
      title: 'Timing',
      subtitle:
          'You can leave timing open, lock exact dates, or guide AI with a preferred month and stay length.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TimingModeOption(
            icon: Icons.auto_awesome_outlined,
            title: 'AI decides',
            subtitle:
                'Let AI suggest the best season and trip length for this idea.',
            isSelected: timeInputMode == WishlistTimeInputMode.aiRecommended,
            onTap: () =>
                onTimeInputModeChanged(WishlistTimeInputMode.aiRecommended),
          ),
          const SizedBox(height: 10),
          _TimingModeOption(
            icon: Icons.date_range_outlined,
            title: 'Exact dates',
            subtitle: dateRange == null
                ? 'Lock the plan to a precise departure and return window.'
                : '${formatDate(dateRange!.start)} - ${formatDate(dateRange!.end)}',
            isSelected: timeInputMode == WishlistTimeInputMode.preciseDates,
            onTap: () =>
                onTimeInputModeChanged(WishlistTimeInputMode.preciseDates),
          ),
          const SizedBox(height: 10),
          _TimingModeOption(
            icon: Icons.calendar_month_outlined,
            title: 'Month + stay',
            subtitle: _buildMonthAndStaySummary(),
            isSelected: timeInputMode == WishlistTimeInputMode.monthAndDuration,
            onTap: () =>
                onTimeInputModeChanged(WishlistTimeInputMode.monthAndDuration),
          ),
          if (timeInputMode == WishlistTimeInputMode.preciseDates) ...<Widget>[
            const SizedBox(height: 16),
            _TimingActionCard(
              icon: Icons.event_available_outlined,
              title: 'Travel dates',
              value: dateRange == null
                  ? 'Choose exact dates'
                  : '${formatDate(dateRange!.start)} - ${formatDate(dateRange!.end)}',
              actionLabel: dateRange == null ? 'Select' : 'Change',
              onTap: onPickDateRange,
            ),
          ],
          if (timeInputMode ==
              WishlistTimeInputMode.monthAndDuration) ...<Widget>[
            const SizedBox(height: 16),
            _TimingActionCard(
              icon: Icons.calendar_today_outlined,
              title: 'Preferred month',
              value: selectedMonth == null
                  ? 'Choose a month'
                  : _monthName(selectedMonth!),
              actionLabel: selectedMonth == null ? 'Select' : 'Change',
              onTap: () => _showMonthPicker(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose your stay length',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Column(
              children: <Widget>[
                for (var i = 0;
                    i < geminiDurationPreferences.length;
                    i++) ...<Widget>[
                  _DurationOptionCard(
                    option: geminiDurationPreferences[i],
                    isSelected: selectedDurationPreference?.id ==
                        geminiDurationPreferences[i].id,
                    onTap: () {
                      final option = geminiDurationPreferences[i];
                      final nextValue =
                          selectedDurationPreference?.id == option.id
                              ? null
                              : option;
                      onDurationPreferenceChanged(nextValue);
                    },
                  ),
                  if (i != geminiDurationPreferences.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ],
          if (timeInputMode == WishlistTimeInputMode.aiRecommended)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'AI will recommend a practical month and duration based on the destination, purpose, and route.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  String _buildMonthAndStaySummary() {
    if (selectedMonth == null && selectedDurationPreference == null) {
      return 'Choose a preferred month and a stay-length band for AI to work within.';
    }
    final parts = <String>[
      if (selectedMonth != null) _monthName(selectedMonth!),
    ];
    return parts.join('  •  ');
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    final pickedMonth = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MonthPickerSheet(selectedMonth: selectedMonth),
    );
    if (pickedMonth == null) {
      return;
    }
    onMonthChanged(pickedMonth == _clearMonthSelection ? null : pickedMonth);
  }
}

class _TimingModeOption extends StatelessWidget {
  const _TimingModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 26,
      blurSigma: 16,
      color: (isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest)
          .withValues(alpha: isSelected ? 0.58 : 0.32),
      borderColor: (isSelected ? scheme.primary : scheme.outlineVariant)
          .withValues(alpha: isSelected ? 0.28 : 0.16),
      shadowColor: scheme.primary.withValues(alpha: isSelected ? 0.1 : 0.05),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isSelected
                            ? scheme.primary
                            : scheme.surfaceContainerHighest)
                        .withValues(alpha: isSelected ? 0.18 : 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimingActionCard extends StatelessWidget {
  const _TimingActionCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 24,
      blurSigma: 14,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
      borderColor: scheme.outlineVariant.withValues(alpha: 0.12),
      shadowColor: scheme.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.46),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _DurationOptionCard extends StatelessWidget {
  const _DurationOptionCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final GeminiDurationPreference option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 24,
      blurSigma: 14,
      color: (isSelected ? scheme.primaryContainer : scheme.surface)
          .withValues(alpha: isSelected ? 0.56 : 0.34),
      borderColor: (isSelected ? scheme.primary : scheme.outlineVariant)
          .withValues(alpha: isSelected ? 0.26 : 0.14),
      shadowColor: scheme.primary.withValues(alpha: isSelected ? 0.08 : 0.04),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        option.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${option.minDays}-${option.maxDays} days',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthPickerSheet extends StatelessWidget {
  const _MonthPickerSheet({required this.selectedMonth});

  final int? selectedMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: FrostedSquircle(
          radius: 32,
          blurSigma: 22,
          color: scheme.surface.withValues(alpha: 0.9),
          borderColor: scheme.primaryContainer.withValues(alpha: 0.18),
          shadowColor: scheme.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Preferred month',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pick the month you want AI to optimize around.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (var month = 1; month <= DateTime.december; month += 1)
                    _MonthChip(
                      label: _monthName(month),
                      isSelected: selectedMonth == month,
                      onTap: () => Navigator.of(context).pop(month),
                    ),
                ],
              ),
              if (selectedMonth != null) ...<Widget>[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_clearMonthSelection),
                    child: const Text('Clear month'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: (isSelected ? scheme.primaryContainer : scheme.surface)
                .withValues(alpha: isSelected ? 0.8 : 0.45),
            border: Border.all(
              color: (isSelected ? scheme.primary : scheme.outlineVariant)
                  .withValues(alpha: isSelected ? 0.28 : 0.18),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color:
                      isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
          ),
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
