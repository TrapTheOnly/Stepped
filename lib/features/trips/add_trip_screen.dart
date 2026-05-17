import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/editorial_overlay_page_shell.dart';
import '../../widgets/frosted_squircle.dart';
import '../map/map_viewmodel.dart';
import '../wishlist/gemini_trip_planner.dart';
import '../wishlist/wishlist_plan_date_utils.dart';
import '../wishlist/widgets/wishlist_editorial_widgets.dart';
import 'add_trip_controller.dart';
import 'add_trip_form_types.dart';
import 'add_trip_logic.dart';
import 'trip_city_detail_screen.dart';
import 'trip_city_models.dart';
import 'widgets/add_trip_destination_preview.dart';
import 'widgets/add_trip_form_sections.dart';

const _editorContentBottomPadding = 48.0;

class AddTripScreen extends ConsumerStatefulWidget {
  const AddTripScreen({
    super.key,
    this.tripId,
    this.wishlistItemId,
    this.initialCountryCode,
    this.initialCountryName,
  });

  final int? tripId;
  final int? wishlistItemId;
  final String? initialCountryCode;
  final String? initialCountryName;

  @override
  ConsumerState<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends ConsumerState<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countryFieldKey = GlobalKey();
  final _countrySearchController = TextEditingController();
  final _countryFocusNode = FocusNode();
  final _cityInputController = TextEditingController();
  final _coverImageController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _populatedFromExisting = false;
  bool _populatedFromWishlist = false;
  String? _selectedCountryCode;
  String? _selectedCountryName;
  String? _countryValidationError;
  String? _cityValidationError;
  int? _sourceWishlistItemId;
  List<TripCityEntry> _tripCities = const <TripCityEntry>[];
  Map<String, TripCountryOption> _countryByCode =
      const <String, TripCountryOption>{};

  bool get _isEditing => widget.tripId != null;

  @override
  void initState() {
    super.initState();
    _selectedCountryCode = widget.initialCountryCode?.trim().toUpperCase();
    _selectedCountryName = widget.initialCountryName?.trim();
  }

  @override
  void dispose() {
    _countrySearchController.dispose();
    _countryFocusNode.dispose();
    _cityInputController.dispose();
    _coverImageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingTripAsync = _isEditing
        ? ref.watch(tripByIdProvider(widget.tripId!))
        : const AsyncValue<TripRecord?>.data(null);
    final countriesAsync = ref.watch(globeCountryDatasetProvider);
    final submitState = ref.watch(addTripControllerProvider);
    final currentWishlistId = widget.wishlistItemId ??
        existingTripAsync.valueOrNull?.sourceWishlistItemId;
    final wishlistItemAsync = currentWishlistId == null
        ? const AsyncValue<WishlistItemRecord?>.data(null)
        : ref.watch(wishlistItemProvider(currentWishlistId));
    final colorScheme = Theme.of(context).colorScheme;
    final inputTheme = roundedTripInputDecorationTheme(context);
    final canRenderForm = _canRenderForm(
      countriesAsync: countriesAsync,
      existingTripAsync: existingTripAsync,
      wishlistItemAsync: wishlistItemAsync,
    );

    return Theme(
      data: Theme.of(context).copyWith(inputDecorationTheme: inputTheme),
      child: EditorialOverlayPageShell(
        background: const _TripEditorAtmosphere(),
        backgroundColor: colorScheme.surface,
        topBar: _EditorTopBar(
          title: _isEditing ? 'Edit Trip' : 'Add Trip',
          onBack: () => context.pop(),
        ),
        bodyBuilder: (context, topContentInset, __) {
          return Column(
            children: <Widget>[
              Expanded(
                child: _buildBody(
                  context: context,
                  topContentInset: topContentInset,
                  existingTripAsync: existingTripAsync,
                  countriesAsync: countriesAsync,
                  wishlistItemAsync: wishlistItemAsync,
                  submitState: submitState,
                ),
              ),
              if (canRenderForm)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: _EditorDockButton(
                      label: _isEditing ? 'Update Trip' : 'Save Trip',
                      isLoading: submitState.isLoading,
                      onTap: submitState.isLoading ? null : _submit,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required double topContentInset,
    required AsyncValue<TripRecord?> existingTripAsync,
    required AsyncValue<dynamic> countriesAsync,
    required AsyncValue<WishlistItemRecord?> wishlistItemAsync,
    required AsyncValue<void> submitState,
  }) {
    return existingTripAsync.when(
      loading: () => const _EditorStatusView(
        title: 'Opening trip editor',
        message: 'Loading your latest travel details.',
        showProgress: true,
      ),
      error: (error, _) => _EditorStatusView(
        title: 'Trip unavailable',
        message: 'Failed to load trip: $error',
      ),
      data: (existingTrip) => _buildEditorContent(
        context: context,
        topContentInset: topContentInset,
        existingTrip: existingTrip,
        countriesAsync: countriesAsync,
        wishlistItemAsync: wishlistItemAsync,
        submitState: submitState,
      ),
    );
  }

  Widget _buildEditorContent({
    required BuildContext context,
    required double topContentInset,
    required TripRecord? existingTrip,
    required AsyncValue<dynamic> countriesAsync,
    required AsyncValue<WishlistItemRecord?> wishlistItemAsync,
    required AsyncValue<void> submitState,
  }) {
    if (_isEditing && existingTrip == null) {
      return const _EditorStatusView(
        title: 'Trip not found',
        message: 'This journey could not be loaded right now.',
      );
    }

    if (!_populatedFromExisting && existingTrip != null) {
      _populateFromExisting(existingTrip);
    }

    if (!_isEditing && widget.wishlistItemId != null) {
      if (wishlistItemAsync.isLoading && !_populatedFromWishlist) {
        return const _EditorStatusView(
          title: 'Loading wishlist trip',
          message: 'Bringing in your saved itinerary and city list.',
          showProgress: true,
        );
      }
      if (wishlistItemAsync.hasError && !_populatedFromWishlist) {
        return _EditorStatusView(
          title: 'Wishlist unavailable',
          message: 'Failed to load wishlist trip: ${wishlistItemAsync.error}',
        );
      }
    }

    if (countriesAsync.hasError) {
      return _EditorStatusView(
        title: 'Country index unavailable',
        message: 'Failed to load countries: ${countriesAsync.error}',
      );
    }

    final countryDataset = countriesAsync.valueOrNull;
    if (countryDataset == null) {
      return const _EditorStatusView(
        title: 'Loading country index',
        message: 'Preparing destinations for search.',
        showProgress: true,
      );
    }

    final planner = ref.read(geminiTripPlannerProvider);
    final inheritance = buildTripWishlistInheritance(
      item: wishlistItemAsync.valueOrNull,
      planner: planner,
    );

    if (!_isEditing &&
        !_populatedFromWishlist &&
        widget.wishlistItemId != null &&
        wishlistItemAsync.valueOrNull != null) {
      _populateFromWishlist(wishlistItemAsync.valueOrNull!, inheritance);
    }

    final countries = buildTripCountryOptions(
      countryDataset.countries,
      existingTrip: existingTrip,
      selectedCountryCode: _selectedCountryCode,
      selectedCountryName: _selectedCountryName,
    );
    _countryByCode = <String, TripCountryOption>{
      for (final country in countries) country.code: country,
    };

    if (_selectedCountryCode != null && _countrySearchController.text.isEmpty) {
      final selected = _countryByCode[_selectedCountryCode!];
      if (selected != null) {
        _selectedCountryName ??= selected.name;
        _countrySearchController.text = selected.name;
      }
    }

    final suggestedCities = buildTripCitySuggestions(
      cities: _tripCities,
      inheritance: inheritance,
    );

    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          16,
          topContentInset,
          16,
          _editorContentBottomPadding,
        ),
        children: <Widget>[
          AddTripDestinationPreview(
            countryCode: _selectedCountryCode,
            countryName: _selectedCountryName,
            coverImageUri: _coverImageController.text,
            startDate: _startDate,
            endDate: _endDate,
          ),
          const SizedBox(height: 18),
          AddTripDestinationSection(
            countryFieldKey: _countryFieldKey,
            countryFocusNode: _countryFocusNode,
            countrySearchController: _countrySearchController,
            countries: countries,
            countryValidationError: _countryValidationError,
            onTyped: (value) {
              final selected = _selectedCountryName;
              if (selected != null &&
                  value.trim().toLowerCase() != selected.trim().toLowerCase()) {
                setState(() {
                  _selectedCountryCode = null;
                  _selectedCountryName = null;
                });
              }
              if (_countryValidationError != null && value.trim().isNotEmpty) {
                setState(() {
                  _countryValidationError = null;
                });
              }
            },
            onSelected: (country) {
              setState(() {
                _selectedCountryCode = country.code;
                _selectedCountryName = country.name;
                _countryValidationError = null;
                _countrySearchController.text = country.name;
              });
            },
          ),
          const SizedBox(height: 12),
          AddTripTravelDetailsSection(
            startDate: _startDate,
            endDate: _endDate,
            cityInputController: _cityInputController,
            cities: _tripCities,
            cityValidationError: _cityValidationError,
            suggestedCities: suggestedCities,
            inheritedSourceTitle: inheritance?.item.title,
            inheritance: inheritance,
            onPickDateRange: _pickDateRange,
            onAddTypedCities: _addTypedCities,
            onAddSuggestedCity: _addSuggestedCity,
            onOpenCity: (city) => _openCityEditor(
              city,
              inheritedPlan: inheritance?.cityPlanFor(city.name),
              inheritedDetail: inheritance?.cityDetailFor(city.name),
            ),
            onRemoveCity: _removeCity,
          ),
          const SizedBox(height: 12),
          AddTripMediaNotesSection(
            coverImageController: _coverImageController,
            notesController: _notesController,
            onPickCoverImageFromDevice: _pickCoverImageFromDevice,
            onClearCoverImage: () {
              _coverImageController.clear();
              setState(() {});
            },
          ),
          if (submitState.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _InlineErrorView(message: '${submitState.error}'),
            ),
        ],
      ),
    );
  }

  bool _canRenderForm({
    required AsyncValue<dynamic> countriesAsync,
    required AsyncValue<TripRecord?> existingTripAsync,
    required AsyncValue<WishlistItemRecord?> wishlistItemAsync,
  }) {
    if (countriesAsync.valueOrNull == null || countriesAsync.hasError) {
      return false;
    }
    if (_isEditing && existingTripAsync.valueOrNull == null) {
      return false;
    }
    if (!_isEditing &&
        widget.wishlistItemId != null &&
        wishlistItemAsync.valueOrNull == null &&
        !_populatedFromWishlist) {
      return false;
    }
    return true;
  }

  void _populateFromExisting(TripRecord trip) {
    _selectedCountryCode = trip.countryCode.toUpperCase();
    _selectedCountryName = trip.countryName;
    _countrySearchController.text = trip.countryName;
    _coverImageController.text = trip.coverImageUri ?? '';
    _notesController.text = trip.notes ?? '';
    _startDate = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
    _endDate = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
    _sourceWishlistItemId = trip.sourceWishlistItemId;
    _tripCities = decodeTripCityEntries(
      cityDataJson: trip.cityDataJson,
      legacyCities: trip.cities,
    );
    _populatedFromExisting = true;
  }

  void _populateFromWishlist(
    WishlistItemRecord item,
    TripWishlistInheritance? inheritance,
  ) {
    final fallbackCities = buildTripCityEntriesFromWishlist(inheritance);
    _selectedCountryCode = item.countryCode?.trim().toUpperCase();
    _selectedCountryName = item.countryName?.trim();
    if (_selectedCountryName != null && _countrySearchController.text.isEmpty) {
      _countrySearchController.text = _selectedCountryName!;
    }
    if (_startDate == null && item.plannedStartDate != null) {
      _startDate = DateTime.fromMillisecondsSinceEpoch(item.plannedStartDate!);
    }
    if (_endDate == null && item.plannedEndDate != null) {
      _endDate = DateTime.fromMillisecondsSinceEpoch(item.plannedEndDate!);
    }
    if (_tripCities.isEmpty) {
      _tripCities = fallbackCities;
    }
    if (_coverImageController.text.trim().isEmpty) {
      final inheritedCover = wishlistPrimaryImageUrl(item)?.trim();
      if (inheritedCover != null && inheritedCover.isNotEmpty) {
        _coverImageController.text = inheritedCover;
      }
    }
    _sourceWishlistItemId = item.id;
    _populatedFromWishlist = true;
  }

  Future<void> _pickDateRange() async {
    final currentRange = _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null;
    final picked = await pickWishlistDateRange(
      context: context,
      currentRange: currentRange,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
  }

  Future<void> _pickCoverImageFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }

    _coverImageController.text = path.trim();
    setState(() {});
  }

  void _addTypedCities() {
    final parsedCities = parseTripCityNames(_cityInputController.text);
    if (parsedCities.isEmpty) {
      return;
    }
    setState(() {
      _tripCities = sanitizeTripCityEntries(
        <TripCityEntry>[
          ..._tripCities,
          ...parsedCities.map((city) => TripCityEntry(name: city)),
        ],
      );
      _cityInputController.clear();
      _cityValidationError = null;
    });
  }

  void _addSuggestedCity(String cityName) {
    setState(() {
      _tripCities = sanitizeTripCityEntries(
        <TripCityEntry>[
          ..._tripCities,
          TripCityEntry(name: cityName),
        ],
      );
      _cityValidationError = null;
    });
  }

  void _removeCity(TripCityEntry city) {
    final cityKey = normalizeTripCityName(city.name);
    setState(() {
      _tripCities = _tripCities
          .where((entry) => normalizeTripCityName(entry.name) != cityKey)
          .toList(growable: false);
      if (_tripCities.isNotEmpty) {
        _cityValidationError = null;
      }
    });
  }

  Future<void> _openCityEditor(
    TripCityEntry city, {
    GeminiCityPlan? inheritedPlan,
    GeminiCityDetail? inheritedDetail,
  }) async {
    final updatedCity = await Navigator.of(context).push<TripCityEntry>(
      MaterialPageRoute<TripCityEntry>(
        builder: (_) => TripCityDetailScreen(
          city: city,
          countryName:
              _selectedCountryName ?? _countrySearchController.text.trim(),
          inheritedPlan: inheritedPlan,
          inheritedDetail: inheritedDetail,
        ),
      ),
    );

    if (!mounted || updatedCity == null) {
      return;
    }

    final originalKey = normalizeTripCityName(city.name);
    setState(() {
      _tripCities = _tripCities
          .map(
            (entry) => normalizeTripCityName(entry.name) == originalKey
                ? updatedCity
                : entry,
          )
          .toList(growable: false);
      _cityValidationError = null;
    });
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    final selectedCountryCode = _selectedCountryCode?.trim().toUpperCase();
    final selectedCountryName = selectedCountryCode == null
        ? null
        : _countryByCode[selectedCountryCode]?.name ?? _selectedCountryName;
    final sanitizedCities = sanitizeTripCityEntries(_tripCities);

    if (!isValid || _startDate == null || _endDate == null) {
      setState(() {});
      return;
    }

    if (selectedCountryCode == null ||
        selectedCountryName == null ||
        selectedCountryName.trim().isEmpty) {
      setState(() => _countryValidationError = 'Choose a destination');
      return;
    }

    if (sanitizedCities.isEmpty) {
      setState(() => _cityValidationError = 'Add at least one city');
      return;
    }

    final success = await ref.read(addTripControllerProvider.notifier).submit(
          tripId: widget.tripId,
          countryCode: selectedCountryCode,
          countryName: selectedCountryName,
          startDate: _startDate!,
          endDate: _endDate!,
          cities: joinTripCityNames(sanitizedCities),
          sourceWishlistItemId: _sourceWishlistItemId,
          cityDataJson: encodeTripCityEntries(sanitizedCities),
          coverImageUri: _coverImageController.text,
          notes: _notesController.text,
        );

    if (!mounted || !success) {
      return;
    }

    context.pop();
  }
}

class _EditorStatusView extends StatelessWidget {
  const _EditorStatusView({
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = editorialOverlayTopContentInsetOf(context, fallback: 24);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                if (showProgress) ...<Widget>[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 6),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripEditorAtmosphere extends StatelessWidget {
  const _TripEditorAtmosphere();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surface.withValues(alpha: 0.08),
            scheme.surface,
          ],
        ),
      ),
    );
  }
}

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 16,
      color: scheme.surface.withValues(alpha: 0.58),
      borderColor: scheme.primaryContainer.withValues(alpha: 0.14),
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        height: 34,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

class _EditorDockButton extends StatelessWidget {
  const _EditorDockButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 18,
      color: scheme.primaryContainer.withValues(alpha: 0.76),
      borderColor: scheme.outlineVariant.withValues(alpha: 0.14),
      shadowColor: scheme.primary.withValues(alpha: 0.08),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 60,
            child: Center(
              child: isLoading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimaryContainer,
                      ),
                    )
                  : Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineErrorView extends StatelessWidget {
  const _InlineErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
        ),
      ),
    );
  }
}
