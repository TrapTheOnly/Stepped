import 'package:flutter/material.dart';

import '../gemini_trip_models.dart';
import '../wishlist_plan_form_types.dart';
import '../wishlist_credits_client.dart';
import 'wishlist_plan_city_preferences_section.dart';
import 'wishlist_plan_credits_card.dart';
import 'wishlist_plan_destination_section.dart';
import 'wishlist_plan_generation_section.dart';
import 'wishlist_plan_header_card.dart';
import 'wishlist_plan_missing_ai_config_card.dart';
import 'wishlist_plan_timing_section.dart';

class WishlistPlanLoadedView extends StatelessWidget {
  const WishlistPlanLoadedView({
    super.key,
    required this.itemTitle,
    required this.hasAiConfiguration,
    required this.usingCloudApi,
    required this.datasetIsLoading,
    required this.datasetError,
    required this.options,
    required this.countryController,
    required this.countryFocusNode,
    required this.selectedCountryCode,
    required this.selectedCountryName,
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
  final bool hasAiConfiguration;
  final bool usingCloudApi;
  final bool datasetIsLoading;
  final Object? datasetError;
  final List<WishlistCountryOption> options;
  final TextEditingController countryController;
  final FocusNode countryFocusNode;
  final String? selectedCountryCode;
  final String selectedCountryName;
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: <Widget>[
        WishlistPlanHeaderCard(itemTitle: itemTitle),
        const SizedBox(height: 12),
        if (credits != null) ...<Widget>[
          WishlistPlanCreditsCard(credits: credits!),
        ] else if (creditsLoading) ...<Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('Loading credit balance...')),
                ],
              ),
            ),
          ),
        ] else if (creditsError != null) ...<Widget>[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Could not load credits right now.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
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
          selectedCountryCode: selectedCountryCode,
          selectedCountryName: selectedCountryName,
          onCountrySelected: onCountrySelected,
          onCountryInputChanged: onCountryInputChanged,
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
          canGenerate: canGenerate,
          isGenerating: isGenerating,
          errorText: errorText,
          plan: plan,
          onGenerate: onGenerate,
          generationCostCredits: generationCostCredits,
          maxOutputTokens: maxOutputTokens,
        ),
      ],
    );
  }
}
