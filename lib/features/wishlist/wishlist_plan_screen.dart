import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../map/map_viewmodel.dart';
import '../settings/app_preferences.dart';
import 'cloud_trip_planner_client.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_date_utils.dart';
import 'wishlist_plan_form_types.dart';
import 'wishlist_credits_client.dart';
import 'wishlist_plan_limits.dart';
import 'wishlist_plan_logic.dart';
import 'widgets/wishlist_plan_loaded_view.dart';

class WishlistPlanScreen extends ConsumerStatefulWidget {
  const WishlistPlanScreen({super.key, required this.itemId});

  final int itemId;

  @override
  ConsumerState<WishlistPlanScreen> createState() => _WishlistPlanScreenState();
}

class _WishlistPlanScreenState extends ConsumerState<WishlistPlanScreen> {
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _citiesController = TextEditingController();
  final FocusNode _countryFocusNode = FocusNode();
  bool _didHydrate = false;
  bool _noCities = true;
  bool _allowAdditionalCities = true;
  bool _isGenerating = false;
  WishlistTimeInputMode _timeInputMode = WishlistTimeInputMode.aiRecommended;
  DateTimeRange? _dateRange;
  int? _selectedMonth;
  GeminiDurationPreference? _selectedDurationPreference;
  String? _selectedCountryCode;
  GeminiTripPlan? _plan;
  String? _errorText;
  Map<String, WishlistCountryOption> _countriesByCode =
      const <String, WishlistCountryOption>{};

  @override
  void dispose() {
    _countryController.dispose();
    _citiesController.dispose();
    _countryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(wishlistItemProvider(widget.itemId));
    final datasetAsync = ref.watch(globeCountryDatasetProvider);
    final creditsAsync = ref.watch(wishlistCreditsProvider);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Plan Editor')),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load item: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Wishlist item not found.'));
          }
          final options = buildWishlistCountryOptions(datasetAsync.valueOrNull);
          _countriesByCode = {
            for (final option in options) option.code.toUpperCase(): option,
          };
          if (!_didHydrate) {
            _hydrateFromItem(item);
          }
          final selectedCountryName = resolveWishlistCountryName(
            typedCountry: _countryController.text,
            selectedCountryCode: _selectedCountryCode,
            countriesByCode: _countriesByCode,
          );
          final hasPreferredCityInput =
              !_noCities && _citiesController.text.trim().isNotEmpty;
          final preferredCityAnalysis =
              analyzeWishlistCityInput(_citiesController.text);
          final cityInputError = validateWishlistCityInput(
            noCities: _noCities,
            rawCities: _citiesController.text,
          );
          final usingCloudApi = prefs.aiPlannerSource == AiPlannerSource.cloud;
          final hasCloudApiBaseUrl = prefs.cloudAiBaseUrl.trim().isNotEmpty;
          final hasLocalGeminiKey = prefs.geminiApiKey.trim().isNotEmpty;
          final hasAiConfiguration =
              usingCloudApi ? hasCloudApiBaseUrl : hasLocalGeminiKey;
          final canGenerate = !_isGenerating &&
              hasAiConfiguration &&
              selectedCountryName.isNotEmpty &&
              cityInputError == null;

          return WishlistPlanLoadedView(
            itemTitle: item.title,
            hasAiConfiguration: hasAiConfiguration,
            usingCloudApi: usingCloudApi,
            datasetIsLoading: datasetAsync.isLoading,
            datasetError: datasetAsync.hasError ? datasetAsync.error : null,
            options: options,
            countryController: _countryController,
            countryFocusNode: _countryFocusNode,
            selectedCountryCode: _selectedCountryCode,
            selectedCountryName: selectedCountryName,
            timeInputMode: _timeInputMode,
            dateRange: _dateRange,
            selectedMonth: _selectedMonth,
            selectedDurationPreference: _selectedDurationPreference,
            noCities: _noCities,
            allowAdditionalCities: _allowAdditionalCities,
            citiesController: _citiesController,
            hasPreferredCityInput: hasPreferredCityInput,
            cityValidationText: cityInputError,
            preferredCityCount: preferredCityAnalysis.uniqueCount,
            maxCitiesPerRequest: wishlistMaxCitiesPerRequest,
            canGenerate: canGenerate,
            isGenerating: _isGenerating,
            errorText: _errorText,
            plan: _plan,
            generationCostCredits:
                creditsAsync.valueOrNull?.generationCostCredits ??
                    wishlistPlanGenerationCostCredits,
            maxOutputTokens: wishlistPlannerMaxOutputTokens,
            credits: creditsAsync.valueOrNull,
            creditsLoading: creditsAsync.isLoading,
            creditsError: creditsAsync.hasError ? creditsAsync.error : null,
            onOpenSettings: () => context.push('/profile/settings'),
            onCountrySelected: (option) {
              setState(() {
                _selectedCountryCode = option.code;
                _errorText = null;
              });
            },
            onCountryInputChanged: _syncCountrySelection,
            onTimeInputModeChanged: (mode) {
              setState(() {
                _timeInputMode = mode;
                _errorText = null;
                if (_timeInputMode != WishlistTimeInputMode.preciseDates) {
                  _dateRange = null;
                }
                if (_timeInputMode != WishlistTimeInputMode.monthAndDuration) {
                  _selectedMonth = null;
                  _selectedDurationPreference = null;
                }
              });
            },
            onPickDateRange: () async {
              final picked = await pickWishlistDateRange(
                context: context,
                currentRange: _dateRange,
              );
              if (picked == null) {
                return;
              }
              setState(() {
                _dateRange = picked;
                _errorText = null;
              });
            },
            onMonthChanged: (value) {
              setState(() {
                _selectedMonth = value;
                _errorText = null;
              });
            },
            onDurationPreferenceChanged: (value) {
              setState(() {
                _selectedDurationPreference = value;
                _errorText = null;
              });
            },
            onNoCitiesChanged: (value) {
              setState(() {
                _noCities = value;
                _errorText = null;
                if (value) {
                  _citiesController.clear();
                }
              });
            },
            onCitiesChanged: (_) {
              setState(() {
                _errorText = null;
              });
            },
            onAllowAdditionalCitiesChanged: (value) {
              setState(() {
                _allowAdditionalCities = value;
                _errorText = null;
              });
            },
            onGenerate: () => _generatePlan(item, prefs),
            formatDate: formatWishlistDate,
          );
        },
      ),
    );
  }

  void _hydrateFromItem(WishlistItemRecord item) {
    final hydrated = hydrateWishlistStateFromItem(
      item: item,
      planner: ref.read(geminiTripPlannerProvider),
    );
    _countryController.text = hydrated.countryText;
    _selectedCountryCode = hydrated.selectedCountryCode;
    _citiesController.text = hydrated.citiesText;
    _noCities = hydrated.noCities;
    _timeInputMode = hydrated.timeInputMode;
    _dateRange = hydrated.dateRange;
    _selectedMonth = hydrated.selectedMonth;
    _selectedDurationPreference = hydrated.selectedDurationPreference;
    _allowAdditionalCities = hydrated.allowAdditionalCities;
    _plan = hydrated.plan;
    _didHydrate = true;
  }

  void _syncCountrySelection(String rawValue) {
    setState(() {
      _selectedCountryCode = findSelectedCountryCodeFromQuery(
        rawValue: rawValue,
        countriesByCode: _countriesByCode,
      );
    });
  }

  Future<void> _generatePlan(
      WishlistItemRecord item, AppPreferences prefs) async {
    final countryName = resolveWishlistCountryName(
      typedCountry: _countryController.text,
      selectedCountryCode: _selectedCountryCode,
      countriesByCode: _countriesByCode,
    );
    final inputError = validateWishlistGenerationInputs(
      countryName: countryName,
      timeInputMode: _timeInputMode,
      dateRange: _dateRange,
      selectedMonth: _selectedMonth,
      selectedDurationPreference: _selectedDurationPreference,
      noCities: _noCities,
      rawCities: _citiesController.text,
    );
    if (inputError != null) {
      setState(() {
        _errorText = inputError;
      });
      return;
    }
    setState(() {
      _isGenerating = true;
      _errorText = null;
    });
    try {
      final planner = ref.read(geminiTripPlannerProvider);
      final finalizedPlan = await generateAndSaveWishlistPlan(
        repository: ref.read(wishlistRepositoryProvider),
        prefs: prefs,
        planner: planner,
        cloudClient: ref.read(cloudTripPlannerClientProvider),
        item: item,
        timeInputMode: _timeInputMode,
        dateRange: _dateRange,
        selectedMonth: _selectedMonth,
        selectedDurationPreference: _selectedDurationPreference,
        countryName: countryName,
        noCities: _noCities,
        rawCities: _citiesController.text,
        allowAdditionalCities: _allowAdditionalCities,
        selectedCountryCode: _selectedCountryCode,
        currentPlan: _plan,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _plan = finalizedPlan;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI plan updated and saved.')),
      );
    } catch (error) {
      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}
