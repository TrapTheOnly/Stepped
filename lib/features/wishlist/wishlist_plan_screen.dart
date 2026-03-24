import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../auth/auth_controller.dart';
import '../map/map_viewmodel.dart';
import '../settings/app_preferences.dart';
import 'cloud_trip_planner_client.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_date_utils.dart';
import 'wishlist_plan_form_types.dart';
import 'wishlist_credits_client.dart';
import 'wishlist_plan_limits.dart';
import 'wishlist_plan_logic.dart';
import 'widgets/wishlist_editor_shell.dart';
import 'widgets/wishlist_editorial_widgets.dart';
import 'widgets/wishlist_plan_loaded_view.dart';

const _wishlistAiPurposeMaxChars = 300;

class WishlistPlanScreen extends ConsumerStatefulWidget {
  const WishlistPlanScreen({super.key, required this.itemId});

  final int itemId;

  @override
  ConsumerState<WishlistPlanScreen> createState() => _WishlistPlanScreenState();
}

class _WishlistPlanScreenState extends ConsumerState<WishlistPlanScreen> {
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _citiesController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final FocusNode _countryFocusNode = FocusNode();
  bool _didHydrate = false;
  bool _noCities = true;
  bool _allowAdditionalCities = true;
  bool _isGenerating = false;
  bool _isSavingDraft = false;
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
    _purposeController.dispose();
    _countryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(wishlistItemProvider(widget.itemId));
    final datasetAsync = ref.watch(globeCountryDatasetProvider);
    final creditsAsync = ref.watch(wishlistCreditsProvider);
    final authController = ref.watch(authControllerProvider);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;
    final selectedCountryName = resolveWishlistCountryName(
      typedCountry: _countryController.text,
      selectedCountryCode: _selectedCountryCode,
      countriesByCode: _countriesByCode,
    );
    final usingCloudApi = prefs.aiPlannerSource == AiPlannerSource.cloud;
    final hasAiConfiguration = usingCloudApi
        ? prefs.cloudAiBaseUrl.trim().isNotEmpty
        : prefs.geminiApiKey.trim().isNotEmpty;
    final canGenerate = !_isGenerating &&
        hasAiConfiguration &&
        selectedCountryName.isNotEmpty &&
        validateWishlistCityInput(
              noCities: _noCities,
              rawCities: _citiesController.text,
            ) ==
            null;

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: wishlistEditorInputDecorationTheme(context),
      ),
      child: WishlistEditorShell(
        title: 'AI Planner',
        onBack: () => context.pop(),
        topActions: <Widget>[
          IconButton(
            onPressed:
                _isGenerating || _isSavingDraft || itemAsync.valueOrNull == null
                    ? null
                    : () => _saveDraft(itemAsync.valueOrNull!),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            visualDensity: VisualDensity.compact,
            icon: _isSavingDraft
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 20),
          ),
        ],
        bottomDock: WishlistEditorDockButton(
          label: _isGenerating ? 'Generating...' : 'Generate with AI',
          icon: Icons.auto_awesome_outlined,
          isLoading: _isGenerating,
          onTap: !canGenerate || itemAsync.valueOrNull == null
              ? null
              : () => _generatePlan(
                    itemAsync.valueOrNull!,
                    prefs,
                    authController.accessToken,
                  ),
        ),
        body: itemAsync.when(
          loading: () => const WishlistEditorStatusView(
            title: 'Opening AI planner',
            message: 'Loading the current wishlist idea and your saved draft.',
            showProgress: true,
          ),
          error: (error, _) => WishlistEditorStatusView(
            title: 'Planner unavailable',
            message: 'Failed to load item: $error',
          ),
          data: (item) {
            if (item == null) {
              return const WishlistEditorStatusView(
                title: 'Wishlist item not found',
                message: 'This wishlist idea is no longer available.',
              );
            }
            final options =
                buildWishlistCountryOptions(datasetAsync.valueOrNull);
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
            return WishlistPlanLoadedView(
              itemTitle: item.title,
              itemImageUrl: wishlistPrimaryImageUrl(item),
              hasAiConfiguration: hasAiConfiguration,
              usingCloudApi: usingCloudApi,
              datasetIsLoading: datasetAsync.isLoading,
              datasetError: datasetAsync.hasError ? datasetAsync.error : null,
              options: options,
              countryController: _countryController,
              countryFocusNode: _countryFocusNode,
              selectedCountryCode: _selectedCountryCode,
              selectedCountryName: selectedCountryName,
              purposeController: _purposeController,
              purposeLength: _purposeController.text.length,
              maxPurposeLength: _wishlistAiPurposeMaxChars,
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
              onPurposeChanged: (_) {
                setState(() {
                  _errorText = null;
                });
              },
              onTimeInputModeChanged: (mode) {
                setState(() {
                  _timeInputMode = mode;
                  _errorText = null;
                  if (_timeInputMode != WishlistTimeInputMode.preciseDates) {
                    _dateRange = null;
                  }
                  if (_timeInputMode !=
                      WishlistTimeInputMode.monthAndDuration) {
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
              onGenerate: () =>
                  _generatePlan(item, prefs, authController.accessToken),
              formatDate: formatWishlistDate,
            );
          },
        ),
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
    _purposeController.text = hydrated.purpose;
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
    WishlistItemRecord item,
    AppPreferences prefs,
    String? accessToken,
  ) async {
    final countryName = resolveWishlistCountryName(
      typedCountry: _countryController.text,
      selectedCountryCode: _selectedCountryCode,
      countriesByCode: _countriesByCode,
    );
    final tripPurpose = _normalizedPurpose();
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
        accessToken: accessToken,
        item: item,
        timeInputMode: _timeInputMode,
        dateRange: _dateRange,
        selectedMonth: _selectedMonth,
        selectedDurationPreference: _selectedDurationPreference,
        countryName: countryName,
        tripPurpose: tripPurpose,
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
      ref.invalidate(wishlistItemProvider(widget.itemId));
      ref.invalidate(wishlistStreamProvider);
      ref.invalidate(wishlistCreditsProvider);
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

  Future<void> _saveDraft(WishlistItemRecord item) async {
    final countryName = resolveWishlistCountryName(
      typedCountry: _countryController.text,
      selectedCountryCode: _selectedCountryCode,
      countriesByCode: _countriesByCode,
    );
    final tripPurpose = _normalizedPurpose();
    if (countryName.isEmpty) {
      setState(() {
        _errorText = 'Please choose a country before saving.';
      });
      return;
    }

    setState(() {
      _isSavingDraft = true;
      _errorText = null;
    });

    try {
      await saveWishlistPlanDraft(
        repository: ref.read(wishlistRepositoryProvider),
        planner: ref.read(geminiTripPlannerProvider),
        item: item,
        countryName: countryName,
        selectedCountryCode: _selectedCountryCode,
        timeInputMode: _timeInputMode,
        dateRange: _dateRange,
        selectedMonth: _selectedMonth,
        selectedDurationPreference: _selectedDurationPreference,
        allowAdditionalCities: _allowAdditionalCities,
        tripPurpose: tripPurpose,
        plannedCities: _noCities ? null : _citiesController.text.trim(),
        plan: _plan,
      );
      ref.invalidate(wishlistItemProvider(widget.itemId));
      ref.invalidate(wishlistStreamProvider);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved.')),
      );
      context.pop();
    } catch (error) {
      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
      }
    }
  }

  String? _normalizedPurpose() {
    final trimmed = _purposeController.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length <= _wishlistAiPurposeMaxChars) {
      return trimmed;
    }
    return trimmed.substring(0, _wishlistAiPurposeMaxChars);
  }
}
