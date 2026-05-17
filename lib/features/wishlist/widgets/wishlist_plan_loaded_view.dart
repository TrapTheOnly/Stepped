import 'package:flutter/material.dart';

import '../gemini_trip_models.dart';
import '../wishlist_plan_form_types.dart';
import '../wishlist_credits_client.dart';
import 'wishlist_plan_city_preferences_section.dart';
import 'wishlist_plan_destination_section.dart';
import 'wishlist_plan_purpose_section.dart';
import 'wishlist_plan_generation_section.dart';
import 'wishlist_plan_missing_ai_config_card.dart';
import 'wishlist_plan_timing_section.dart';
import 'wishlist_editor_shell.dart';

class WishlistPlanLoadedView extends StatelessWidget {
  const WishlistPlanLoadedView({
    super.key,
    required this.itemTitle,
    required this.itemImageUrl,
    required this.hasAiConfiguration,
    required this.usingCloudApi,
    required this.datasetIsLoading,
    required this.datasetError,
    required this.options,
    required this.countryController,
    required this.countryFocusNode,
    required this.selectedCountryName,
    required this.purposeController,
    required this.purposeLength,
    required this.maxPurposeLength,
    required this.timeInputMode,
    required this.dateRange,
    required this.selectedMonth,
    required this.selectedDurationPreference,
    required this.noCities,
    required this.allowAdditionalCities,
    required this.citiesController,
    required this.hasPreferredCityInput,
    required this.cityValidationText,
    required this.preferredCityCount,
    required this.maxCitiesPerRequest,
    required this.canGenerate,
    required this.isGenerating,
    required this.errorText,
    required this.plan,
    required this.generationCostCredits,
    required this.maxOutputTokens,
    required this.credits,
    required this.creditsLoading,
    required this.creditsError,
    required this.onOpenSettings,
    required this.onCountrySelected,
    required this.onCountryInputChanged,
    required this.onPurposeChanged,
    required this.onTimeInputModeChanged,
    required this.onPickDateRange,
    required this.onMonthChanged,
    required this.onDurationPreferenceChanged,
    required this.onNoCitiesChanged,
    required this.onCitiesChanged,
    required this.onAllowAdditionalCitiesChanged,
    required this.onGenerate,
    required this.formatDate,
  });

  final String itemTitle;
  final String? itemImageUrl;
  final bool hasAiConfiguration;
  final bool usingCloudApi;
  final bool datasetIsLoading;
  final Object? datasetError;
  final List<WishlistCountryOption> options;
  final TextEditingController countryController;
  final FocusNode countryFocusNode;
  final String selectedCountryName;
  final TextEditingController purposeController;
  final int purposeLength;
  final int maxPurposeLength;
  final WishlistTimeInputMode timeInputMode;
  final DateTimeRange? dateRange;
  final int? selectedMonth;
  final GeminiDurationPreference? selectedDurationPreference;
  final bool noCities;
  final bool allowAdditionalCities;
  final TextEditingController citiesController;
  final bool hasPreferredCityInput;
  final String? cityValidationText;
  final int preferredCityCount;
  final int maxCitiesPerRequest;
  final bool canGenerate;
  final bool isGenerating;
  final String? errorText;
  final GeminiTripPlan? plan;
  final int generationCostCredits;
  final int maxOutputTokens;
  final WishlistCreditsSnapshot? credits;
  final bool creditsLoading;
  final Object? creditsError;
  final VoidCallback onOpenSettings;
  final ValueChanged<WishlistCountryOption> onCountrySelected;
  final ValueChanged<String> onCountryInputChanged;
  final ValueChanged<String> onPurposeChanged;
  final ValueChanged<WishlistTimeInputMode> onTimeInputModeChanged;
  final VoidCallback onPickDateRange;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<GeminiDurationPreference?> onDurationPreferenceChanged;
  final ValueChanged<bool> onNoCitiesChanged;
  final ValueChanged<String> onCitiesChanged;
  final ValueChanged<bool> onAllowAdditionalCitiesChanged;
  final VoidCallback onGenerate;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final subtitle = selectedCountryName.isNotEmpty
        ? selectedCountryName
        : 'Shape the destination, timing, and route with AI';

    return ListView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        wishlistEditorTopOverlayClearanceOf(context),
        16,
        wishlistEditorBottomDockClearance + 48,
      ),
      children: <Widget>[
        WishlistEditorHeroCard(
          title: itemTitle,
          badge: 'AI planner',
          subtitle: subtitle,
          imageUrl: itemImageUrl,
          chips: <String>[
            if (timeInputMode == WishlistTimeInputMode.preciseDates &&
                dateRange != null)
              '${formatDate(dateRange!.start)} - ${formatDate(dateRange!.end)}',
            if (timeInputMode == WishlistTimeInputMode.aiRecommended &&
                plan?.recommendedDates != null)
              '${formatDate(plan!.recommendedDates!.start)} - ${formatDate(plan!.recommendedDates!.end)}',
            if (timeInputMode == WishlistTimeInputMode.monthAndDuration &&
                selectedMonth != null)
              _monthName(selectedMonth!),
          ],
        ),
        const SizedBox(height: 18),
        if (!hasAiConfiguration) ...<Widget>[
          WishlistPlanMissingAiConfigCard(
            usingCloudApi: usingCloudApi,
            onOpenSettings: onOpenSettings,
          ),
          const SizedBox(height: 12),
        ],
        WishlistPlanDestinationSection(
          datasetIsLoading: datasetIsLoading,
          datasetError: datasetError,
          options: options,
          countryController: countryController,
          countryFocusNode: countryFocusNode,
          onCountrySelected: onCountrySelected,
          onCountryInputChanged: onCountryInputChanged,
        ),
        const SizedBox(height: 12),
        WishlistPlanPurposeSection(
          controller: purposeController,
          currentLength: purposeLength,
          maxLength: maxPurposeLength,
          onChanged: onPurposeChanged,
        ),
        const SizedBox(height: 12),
        WishlistPlanTimingSection(
          timeInputMode: timeInputMode,
          dateRange: dateRange,
          selectedMonth: selectedMonth,
          selectedDurationPreference: selectedDurationPreference,
          onTimeInputModeChanged: onTimeInputModeChanged,
          onPickDateRange: onPickDateRange,
          onMonthChanged: onMonthChanged,
          onDurationPreferenceChanged: onDurationPreferenceChanged,
          formatDate: formatDate,
        ),
        const SizedBox(height: 12),
        WishlistPlanCityPreferencesSection(
          noCities: noCities,
          allowAdditionalCities: allowAdditionalCities,
          citiesController: citiesController,
          hasPreferredCityInput: hasPreferredCityInput,
          cityValidationText: cityValidationText,
          preferredCityCount: preferredCityCount,
          maxCitiesPerRequest: maxCitiesPerRequest,
          onNoCitiesChanged: onNoCitiesChanged,
          onCitiesChanged: onCitiesChanged,
          onAllowAdditionalCitiesChanged: onAllowAdditionalCitiesChanged,
        ),
        const SizedBox(height: 12),
        WishlistPlanGenerationSection(
          errorText: errorText,
          plan: plan,
          onGenerate: canGenerate ? onGenerate : null,
          isGenerating: isGenerating,
          generationCostCredits: generationCostCredits,
          maxOutputTokens: maxOutputTokens,
        ),
      ],
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
