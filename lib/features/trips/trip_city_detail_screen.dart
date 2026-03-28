import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../widgets/frosted_squircle.dart';
import '../wishlist/gemini_trip_planner.dart';
import '../wishlist/widgets/wishlist_editorial_widgets.dart';
import 'trip_city_models.dart';

const _tripCityTopClearance = 114.0;
const _tripCityEditBottomClearance = 156.0;
const _tripCityViewBottomClearance = 40.0;

enum TripCityScreenMode {
  view,
  edit,
}

class TripCityDetailScreen extends StatefulWidget {
  const TripCityDetailScreen({
    super.key,
    required this.city,
    required this.countryName,
    this.inheritedPlan,
    this.inheritedDetail,
    this.mode = TripCityScreenMode.view,
    this.allowEditing = true,
    this.ownerDisplayName,
  });

  final TripCityEntry city;
  final String countryName;
  final GeminiCityPlan? inheritedPlan;
  final GeminiCityDetail? inheritedDetail;
  final TripCityScreenMode mode;
  final bool allowEditing;
  final String? ownerDisplayName;

  @override
  State<TripCityDetailScreen> createState() => _TripCityDetailScreenState();
}

class _TripCityDetailScreenState extends State<TripCityDetailScreen> {
  late final TextEditingController _visitedPlaceController;
  late final TextEditingController _notesController;
  late final TextEditingController _overviewController;
  late final TextEditingController _suggestedPlaceController;
  late final TextEditingController _stopSlotController;
  late final TextEditingController _stopPlaceController;
  late final TextEditingController _stopNoteController;

  late List<String> _visitedPlaces;
  late List<String> _suggestedPlaces;
  late List<String> _completedSuggestedPlaceKeys;
  late List<TripCityItineraryStop> _itineraryStops;
  late int? _rating;
  String? _imageUri;

  bool get _isEditing => widget.mode == TripCityScreenMode.edit;

  @override
  void initState() {
    super.initState();
    _visitedPlaceController = TextEditingController();
    _notesController = TextEditingController(text: widget.city.notes ?? '');
    _overviewController = TextEditingController(text: _seedOverview());
    _suggestedPlaceController = TextEditingController();
    _stopSlotController = TextEditingController();
    _stopPlaceController = TextEditingController();
    _stopNoteController = TextEditingController();
    _visitedPlaces = List<String>.from(widget.city.visitedPlaces);
    _suggestedPlaces = List<String>.from(_seedSuggestedPlaces());
    _completedSuggestedPlaceKeys = sanitizeTripCompletedSuggestedPlaceKeys(
      widget.city.completedSuggestedPlaceKeys,
      suggestedPlaces: _suggestedPlaces,
    );
    _itineraryStops = List<TripCityItineraryStop>.from(_seedItineraryStops());
    _rating = widget.city.rating;
    _imageUri = widget.city.imageUri?.trim();
  }

  @override
  void dispose() {
    _visitedPlaceController.dispose();
    _notesController.dispose();
    _overviewController.dispose();
    _suggestedPlaceController.dispose();
    _stopSlotController.dispose();
    _stopPlaceController.dispose();
    _stopNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildEditShell(context);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeViewMode();
        }
      },
      child: _buildViewShell(context),
    );
  }

  Widget _buildViewShell(BuildContext context) {
    final isReadOnly = !widget.allowEditing;

    return _TripCityShell(
      title: widget.city.name,
      onBack: _closeViewMode,
      onEdit: widget.allowEditing ? _openEditMode : null,
      body: WishlistScrollView(
        bottomPadding: _tripCityViewBottomClearance,
        children: <Widget>[
          const SizedBox(height: _tripCityTopClearance),
          WishlistHorizontalPadding(
            child: _TripCityHero(
              cityName: widget.city.name,
              countryName: widget.countryName,
              imageUri: _imageUri,
              inheritedPlan: widget.inheritedPlan,
              inheritedDetail: widget.inheritedDetail,
              itineraryStopCount: _itineraryStops.length,
            ),
          ),
          const SizedBox(height: 24),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'City focus',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _TripCityMetaRow(
                    children: <Widget>[
                      if (_plannedDays != null)
                        _TripCityMetaChip(
                          label: '${_plannedDays!} days planned',
                          emphasized: true,
                        ),
                      if (widget.inheritedPlan?.isExtra ?? false)
                        const _TripCityMetaChip(
                          label: 'Extra city',
                          icon: Icons.add_location_alt_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _reasonText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (_overviewText.isNotEmpty &&
                      _overviewText.toLowerCase() != _reasonText.toLowerCase()) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      _overviewText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (!isReadOnly) ...<Widget>[
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickCityImageFromDevice,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Upload image'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _imageUri == null ? null : _clearCityImage,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'Day flow',
              child: _itineraryStops.isEmpty
                  ? Text(
                      'No timeline stops are saved for this city yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  : Column(
                      children: <Widget>[
                        for (var i = 0; i < _itineraryStops.length; i += 1) ...<Widget>[
                          _TripTimelineCard(stop: _itineraryStops[i]),
                          if (i != _itineraryStops.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'Things to do',
              child: _suggestedPlaces.isEmpty
                  ? Text(
                      'No city activities are saved yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${_completedSuggestedPlaceKeys.length}/${_suggestedPlaces.length} checked',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                letterSpacing: 0.3,
                              ),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < _suggestedPlaces.length; i += 1) ...<Widget>[
                          _TripThingChecklistTile(
                            label: _suggestedPlaces[i],
                            checked: _completedSuggestedPlaceKeys.contains(
                              normalizeTripSuggestedPlaceKey(_suggestedPlaces[i]),
                            ),
                            onTap: isReadOnly
                                ? null
                                : () => _toggleSuggestedPlaceCompletion(
                                      _suggestedPlaces[i],
                                    ),
                          ),
                          if (i != _suggestedPlaces.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: isReadOnly ? _readOnlyTakeTitle : 'Your take',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Rating'),
                  const SizedBox(height: 10),
                  if (isReadOnly)
                    _TripCityReadOnlyRatingRow(rating: _rating)
                  else
                    _TripCityRatingRow(
                      rating: _rating,
                      onChanged: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  if (isReadOnly)
                    _TripCityReadOnlyNotes(notes: _notesController.text.trim())
                  else
                    TextFormField(
                      controller: _notesController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'City notes',
                        hintText:
                            'A favorite street, the best coffee, the moment you would repeat...',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'Visited places',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!isReadOnly) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _visitedPlaceController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Add visited place',
                              hintText: 'Blue Mosque, Karakoy Pier',
                            ),
                            onFieldSubmitted: (_) => _addVisitedPlaces(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _addVisitedPlaces,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_visitedPlaces.isEmpty)
                    Text(
                      'Nothing saved yet for this city.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _visitedPlaces
                          .map(
                            (place) => isReadOnly
                                ? _TripReadOnlyPlaceChip(label: place)
                                : _TripVisitedPlaceChip(
                                    label: place,
                                    onRemoved: () => setState(() {
                                      _visitedPlaces = List<String>.from(
                                        _visitedPlaces,
                                      )..remove(place);
                                    }),
                                  ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditShell(BuildContext context) {
    return _TripCityShell(
      title: widget.city.name,
      onBack: () => Navigator.of(context).maybePop(),
      body: WishlistScrollView(
        bottomPadding: _tripCityEditBottomClearance,
        children: <Widget>[
          const SizedBox(height: _tripCityTopClearance),
          WishlistHorizontalPadding(
            child: _TripCityHero(
              cityName: widget.city.name,
              countryName: widget.countryName,
              imageUri: _imageUri,
              inheritedPlan: widget.inheritedPlan,
              inheritedDetail: widget.inheritedDetail,
              itineraryStopCount: _itineraryStops.length,
            ),
          ),
          const SizedBox(height: 24),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'City focus',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (widget.inheritedPlan != null || widget.inheritedDetail != null) ...<Widget>[
                    Text(
                      'Wishlist itinerary available for this stop.',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _TripCityMetaRow(
                    children: <Widget>[
                      if (_plannedDays != null)
                        _TripCityMetaChip(
                          label: '${_plannedDays!} days planned',
                          emphasized: true,
                        ),
                      _TripCityMetaChip(
                        label: _imageUri == null
                            ? 'No city photo yet'
                            : 'Personal city photo',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickCityImageFromDevice,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload image'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _imageUri == null ? null : _clearCityImage,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _overviewController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Overview',
                      hintText:
                          'Why this city matters, the mood, the must-see rhythm...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'Day flow',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_itineraryStops.isEmpty)
                    Text(
                      'No timeline stops are saved for this city yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else
                    Column(
                      children: <Widget>[
                        for (var index = 0;
                            index < _itineraryStops.length;
                            index += 1) ...<Widget>[
                          _TripTimelineCard(
                            stop: _itineraryStops[index],
                            onRemove: () => setState(() {
                              _itineraryStops = List<TripCityItineraryStop>.from(
                                _itineraryStops,
                              )..removeAt(index);
                            }),
                          ),
                          if (index != _itineraryStops.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _stopSlotController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Time slot',
                      hintText: 'Day 1 - Morning',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _stopPlaceController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Place',
                      hintText: 'Galata Tower, Borough Market',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _stopNoteController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText:
                          'What happens here, why it fits, or what to remember...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _addItineraryStop,
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('Add stop'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'Things to do',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _suggestedPlaceController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Add activity or place',
                            hintText:
                                'Grand Bazaar, sunset cruise, food market',
                          ),
                          onFieldSubmitted: (_) => _addSuggestedPlaces(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _addSuggestedPlaces,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_suggestedPlaces.isEmpty)
                    Text(
                      'No city activities are saved yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else
                    Column(
                      children: <Widget>[
                        for (var index = 0;
                            index < _suggestedPlaces.length;
                            index += 1) ...<Widget>[
                          _TripThingTile(
                            label: _suggestedPlaces[index],
                            onRemove: () => setState(() {
                              final removedKey = normalizeTripSuggestedPlaceKey(
                                _suggestedPlaces[index],
                              );
                              _suggestedPlaces = List<String>.from(
                                _suggestedPlaces,
                              )..removeAt(index);
                              _completedSuggestedPlaceKeys =
                                  sanitizeTripCompletedSuggestedPlaceKeys(
                                _completedSuggestedPlaceKeys
                                    .where((key) => key != removedKey)
                                    .toList(growable: false),
                                suggestedPlaces: _suggestedPlaces,
                              );
                            }),
                          ),
                          if (index != _suggestedPlaces.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'Your take',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Rating'),
                  const SizedBox(height: 10),
                  _TripCityRatingRow(
                    rating: _rating,
                    onChanged: (rating) {
                      setState(() {
                        _rating = rating;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'City notes',
                      hintText:
                          'A favorite street, the best coffee, the moment you would repeat...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          WishlistHorizontalPadding(
            child: _TripCitySection(
              title: 'Visited places',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _visitedPlaceController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Add visited place',
                            hintText: 'Blue Mosque, Karakoy Pier',
                          ),
                          onFieldSubmitted: (_) => _addVisitedPlaces(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _addVisitedPlaces,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_visitedPlaces.isEmpty)
                    Text(
                      'Nothing saved yet for this city.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _visitedPlaces
                          .map(
                            (place) => _TripVisitedPlaceChip(
                              label: place,
                              onRemoved: () => setState(() {
                                _visitedPlaces = List<String>.from(
                                  _visitedPlaces,
                                )..remove(place);
                              }),
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomChild: _TripCitySaveButton(onTap: _saveEditMode),
    );
  }

  String get _reasonText {
    final inheritedReason = widget.inheritedPlan?.reason.trim();
    if (inheritedReason != null && inheritedReason.isNotEmpty) {
      return inheritedReason;
    }
    return widget.city.name;
  }

  String get _overviewText => _overviewController.text.trim();

  String get _readOnlyTakeTitle {
    final name = widget.ownerDisplayName?.trim();
    if (name == null || name.isEmpty) {
      return 'Notes & rating';
    }
    final normalized = RegExp(r'[sS]$').hasMatch(name) ? "$name'" : "$name's";
    return '$normalized take';
  }

  int? get _plannedDays {
    final inheritedDays = widget.inheritedPlan?.days;
    if (inheritedDays != null) {
      return inheritedDays;
    }

    final dayLabels = <String>{};
    for (final stop in _itineraryStops) {
      final match = RegExp(r'(day\s*\d+)', caseSensitive: false)
          .firstMatch(stop.slot.trim());
      if (match != null) {
        dayLabels.add(match.group(1)!.toLowerCase());
      }
    }

    if (dayLabels.isNotEmpty) {
      return dayLabels.length;
    }
    if (_itineraryStops.isNotEmpty) {
      return 1;
    }
    return null;
  }

  void _closeViewMode() {
    Navigator.of(context).pop(_buildDraftCity());
  }

  Future<void> _openEditMode() async {
    if (!widget.allowEditing) {
      return;
    }
    final updatedCity = await Navigator.of(context).push<TripCityEntry>(
      MaterialPageRoute<TripCityEntry>(
        builder: (_) => TripCityDetailScreen(
          city: _buildDraftCity(),
          countryName: widget.countryName,
          inheritedPlan: widget.inheritedPlan,
          inheritedDetail: widget.inheritedDetail,
          mode: TripCityScreenMode.edit,
          allowEditing: widget.allowEditing,
        ),
      ),
    );

    if (!mounted || updatedCity == null) {
      return;
    }

    setState(() {
      _applyCity(updatedCity);
    });
  }

  void _applyCity(TripCityEntry city) {
    _rating = city.rating;
    _imageUri = city.imageUri?.trim();
    _notesController.text = city.notes ?? '';
    _overviewController.text = city.itineraryOverview ?? '';
    _visitedPlaces = List<String>.from(city.visitedPlaces);
    _itineraryStops = List<TripCityItineraryStop>.from(city.itineraryStops);
    _suggestedPlaces = List<String>.from(city.suggestedPlaces);
    _completedSuggestedPlaceKeys = sanitizeTripCompletedSuggestedPlaceKeys(
      city.completedSuggestedPlaceKeys,
      suggestedPlaces: _suggestedPlaces,
    );
  }

  String _seedOverview() {
    final manual = widget.city.itineraryOverview?.trim();
    if (manual != null && manual.isNotEmpty) {
      return manual;
    }
    final inheritedOverview = widget.inheritedDetail?.overview.trim();
    if (inheritedOverview != null && inheritedOverview.isNotEmpty) {
      return inheritedOverview;
    }
    final inheritedReason = widget.inheritedPlan?.reason.trim();
    if (inheritedReason != null && inheritedReason.isNotEmpty) {
      return inheritedReason;
    }
    return '';
  }

  List<TripCityItineraryStop> _seedItineraryStops() {
    if (widget.city.itineraryStops.isNotEmpty) {
      return sanitizeTripItineraryStops(widget.city.itineraryStops);
    }
    final timeline =
        widget.inheritedDetail?.timeline ?? const <GeminiTimelineStop>[];
    return timeline
        .map(TripCityItineraryStop.fromGemini)
        .toList(growable: false);
  }

  List<String> _seedSuggestedPlaces() {
    if (widget.city.suggestedPlaces.isNotEmpty) {
      return sanitizeTripSuggestedPlaces(widget.city.suggestedPlaces);
    }
    return sanitizeTripSuggestedPlaces(
      widget.inheritedDetail?.thingsToDo ?? const <String>[],
    );
  }

  Future<void> _pickCityImageFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.single.path?.trim();
    if (path == null || path.isEmpty) {
      return;
    }

    setState(() {
      _imageUri = path;
    });
  }

  void _clearCityImage() {
    setState(() {
      _imageUri = null;
    });
  }

  void _toggleSuggestedPlaceCompletion(String place) {
    final key = normalizeTripSuggestedPlaceKey(place);
    setState(() {
      final next = Set<String>.from(_completedSuggestedPlaceKeys);
      if (next.contains(key)) {
        next.remove(key);
      } else {
        next.add(key);
      }
      _completedSuggestedPlaceKeys = sanitizeTripCompletedSuggestedPlaceKeys(
        next.toList(growable: false),
        suggestedPlaces: _suggestedPlaces,
      );
    });
  }

  void _addSuggestedPlaces() {
    final nextPlaces = parseTripCityNames(_suggestedPlaceController.text);
    if (nextPlaces.isEmpty) {
      return;
    }

    setState(() {
      _suggestedPlaces = sanitizeTripSuggestedPlaces(
        <String>[..._suggestedPlaces, ...nextPlaces],
      );
      _completedSuggestedPlaceKeys = sanitizeTripCompletedSuggestedPlaceKeys(
        _completedSuggestedPlaceKeys,
        suggestedPlaces: _suggestedPlaces,
      );
      _suggestedPlaceController.clear();
    });
  }

  void _addItineraryStop() {
    final place = _stopPlaceController.text.trim();
    if (place.isEmpty) {
      return;
    }

    setState(() {
      _itineraryStops = sanitizeTripItineraryStops(
        <TripCityItineraryStop>[
          ..._itineraryStops,
          TripCityItineraryStop(
            slot: _stopSlotController.text.trim(),
            place: place,
            note: _stopNoteController.text.trim(),
          ),
        ],
      );
      _stopSlotController.clear();
      _stopPlaceController.clear();
      _stopNoteController.clear();
    });
  }

  void _addVisitedPlaces() {
    final nextPlaces = parseTripCityNames(_visitedPlaceController.text);
    if (nextPlaces.isEmpty) {
      return;
    }

    setState(() {
      _visitedPlaces = sanitizeTripVisitedPlaces(
        <String>[..._visitedPlaces, ...nextPlaces],
      );
      _visitedPlaceController.clear();
    });
  }

  TripCityEntry _buildDraftCity() {
    return widget.city.copyWith(
      rating: _rating,
      visitedPlaces: sanitizeTripVisitedPlaces(_visitedPlaces),
      notes:
          _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      imageUri: (_imageUri?.trim().isEmpty ?? true) ? null : _imageUri!.trim(),
      itineraryOverview: _overviewController.text.trim().isEmpty
          ? null
          : _overviewController.text.trim(),
      itineraryStops: sanitizeTripItineraryStops(_itineraryStops),
      suggestedPlaces: sanitizeTripSuggestedPlaces(_suggestedPlaces),
      completedSuggestedPlaceKeys: sanitizeTripCompletedSuggestedPlaceKeys(
        _completedSuggestedPlaceKeys,
        suggestedPlaces: _suggestedPlaces,
      ),
    );
  }

  void _saveEditMode() {
    Navigator.of(context).pop(_buildDraftCity());
  }
}

class _TripCityShell extends StatelessWidget {
  const _TripCityShell({
    required this.title,
    required this.body,
    required this.onBack,
    this.onEdit,
    this.bottomChild,
  });

  final String title;
  final Widget body;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final Widget? bottomChild;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ColoredBox(
        color: scheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(
                child: WishlistAtmosphere(),
              ),
            ),
            Positioned.fill(child: body),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _TripCityTopBar(
                    title: title,
                    onBack: onBack,
                    onEdit: onEdit,
                  ),
                ),
              ),
            ),
            if (bottomChild != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: SafeArea(
                  top: false,
                  child: bottomChild!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TripCityTopBar extends StatelessWidget {
  const _TripCityTopBar({
    required this.title,
    required this.onBack,
    this.onEdit,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onEdit;

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
        height: 42,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
              ),
            ),
            SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerRight,
                child: onEdit == null
                    ? const SizedBox(width: 30, height: 30)
                    : IconButton(
                        onPressed: onEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: scheme.onSurface,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCityHero extends StatelessWidget {
  const _TripCityHero({
    required this.cityName,
    required this.countryName,
    required this.imageUri,
    required this.itineraryStopCount,
    this.inheritedPlan,
    this.inheritedDetail,
  });

  final String cityName;
  final String countryName;
  final String? imageUri;
  final int itineraryStopCount;
  final GeminiCityPlan? inheritedPlan;
  final GeminiCityDetail? inheritedDetail;

  @override
  Widget build(BuildContext context) {
    final imageUrl = inheritedDetail?.image?.imageUrl.trim();
    final activeImageUri = imageUri?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          height: 304,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (activeImageUri != null && activeImageUri.isNotEmpty)
                _TripCityHeroImage(imageUri: activeImageUri)
              else if (imageUrl != null && imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const _TripCityHeroFallback(),
                )
              else
                const _TripCityHeroFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const <double>[0, 0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                child: _TripCityMetaChip(
                  label: inheritedPlan?.isExtra ?? false ? 'Extra city' : 'City guide',
                  emphasized: true,
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      cityName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                            height: 0.98,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      countryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _TripCityMetaRow(
                      children: <Widget>[
                        if (inheritedPlan != null)
                          _TripCityMetaChip(
                            label: '${inheritedPlan!.days} days',
                            icon: Icons.schedule_rounded,
                          ),
                        if (itineraryStopCount > 0)
                          _TripCityMetaChip(
                            label: '$itineraryStopCount stops',
                            icon: Icons.route_outlined,
                          ),
                      ],
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

class _TripCityHeroImage extends StatelessWidget {
  const _TripCityHeroImage({required this.imageUri});

  final String imageUri;

  @override
  Widget build(BuildContext context) {
    if (imageUri.startsWith('http://') || imageUri.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUri,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const _TripCityHeroFallback(),
      );
    }

    final file = File(
      imageUri.startsWith('file://')
          ? imageUri.replaceFirst('file://', '')
          : imageUri,
    );
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }

    return const _TripCityHeroFallback();
  }
}

class _TripCityHeroFallback extends StatelessWidget {
  const _TripCityHeroFallback();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surfaceContainerHigh.withValues(alpha: 0.92),
            scheme.surfaceContainer.withValues(alpha: 0.86),
            scheme.surfaceContainerLow.withValues(alpha: 0.94),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.55, -0.15),
            radius: 1.2,
            colors: <Color>[
              scheme.primary.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _TripCitySection extends StatelessWidget {
  const _TripCitySection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: scheme.surface.withValues(alpha: 0.74),
      borderColor: scheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: scheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TripTimelineCard extends StatelessWidget {
  const _TripTimelineCard({
    required this.stop,
    this.onRemove,
  });

  final TripCityItineraryStop stop;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slot = _parseTimelineSlot(stop.slot);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.9),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _TripCityMetaRow(
              children: <Widget>[
                _TripCityMetaChip(
                  label: slot.dayLabel,
                  emphasized: true,
                ),
                _TripCityMetaChip(
                  label: slot.phaseLabel,
                  icon: Icons.wb_twilight_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.52),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        stop.place,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (stop.note.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          stop.note,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove stop',
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripThingChecklistTile extends StatelessWidget {
  const _TripThingChecklistTile({
    required this.label,
    required this.checked,
    this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: checked
                ? scheme.primaryContainer.withValues(alpha: 0.34)
                : scheme.surfaceContainerLowest.withValues(alpha: 0.88),
            border: Border.all(
              color: checked
                  ? scheme.primary.withValues(alpha: 0.22)
                  : scheme.outlineVariant.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: checked
                        ? scheme.primary
                        : scheme.surface.withValues(alpha: 0.72),
                    border: Border.all(
                      color: checked
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: checked
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: scheme.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          decoration:
                              checked ? TextDecoration.lineThrough : null,
                          color: checked
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripThingTile extends StatelessWidget {
  const _TripThingTile({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: scheme.surfaceContainerLowest.withValues(alpha: 0.88),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripCityRatingRow extends StatelessWidget {
  const _TripCityRatingRow({
    required this.rating,
    required this.onChanged,
  });

  final int? rating;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: List<Widget>.generate(5, (index) {
        final value = index + 1;
        final selected = (rating ?? 0) >= value;
        return IconButton(
          onPressed: () => onChanged(rating == value ? null : value),
          iconSize: 30,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          visualDensity: VisualDensity.compact,
          color: selected ? scheme.tertiary : scheme.outlineVariant,
          icon: Icon(
            selected ? Icons.star_rounded : Icons.star_border_rounded,
          ),
        );
      }),
    );
  }
}

class _TripCityReadOnlyRatingRow extends StatelessWidget {
  const _TripCityReadOnlyRatingRow({required this.rating});

  final int? rating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = rating == null ? 'No rating saved yet.' : '$rating/5';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List<Widget>.generate(5, (index) {
            final selected = (rating ?? 0) >= index + 1;
            return Icon(
              selected ? Icons.star_rounded : Icons.star_border_rounded,
              size: 28,
              color: selected ? scheme.tertiary : scheme.outlineVariant,
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _TripCityReadOnlyNotes extends StatelessWidget {
  const _TripCityReadOnlyNotes({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasNotes = notes.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        hasNotes ? notes : 'No city notes saved yet.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: hasNotes ? scheme.onSurface : scheme.onSurfaceVariant,
              height: 1.45,
            ),
      ),
    );
  }
}

class _TripVisitedPlaceChip extends StatelessWidget {
  const _TripVisitedPlaceChip({
    required this.label,
    required this.onRemoved,
  });

  final String label;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRemoved,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerLowest.withValues(alpha: 0.88),
            shape: StadiumBorder(
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.18),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripReadOnlyPlaceChip extends StatelessWidget {
  const _TripReadOnlyPlaceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.88),
        shape: StadiumBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _TripCityMetaRow extends StatelessWidget {
  const _TripCityMetaRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}

class _TripCityMetaChip extends StatelessWidget {
  const _TripCityMetaChip({
    required this.label,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.38)
            : scheme.surface.withValues(alpha: 0.72),
        shape: StadiumBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCitySaveButton extends StatelessWidget {
  const _TripCitySaveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.pressed)
                  ? Colors.white.withValues(alpha: 0.08)
                  : null,
            ),
            child: Ink(
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    scheme.primary.withValues(alpha: 0.88),
                    scheme.primaryContainer.withValues(alpha: 0.76),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  'Save City',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripTimelineSlot {
  const _TripTimelineSlot({
    required this.dayLabel,
    required this.phaseLabel,
  });

  final String dayLabel;
  final String phaseLabel;
}

_TripTimelineSlot _parseTimelineSlot(String rawSlot) {
  final normalized = rawSlot.trim().replaceAll(RegExp(r'\\s+'), ' ');
  if (normalized.isEmpty) {
    return const _TripTimelineSlot(
      dayLabel: 'Route stop',
      phaseLabel: 'Scheduled',
    );
  }

  final match = RegExp(
    r'^(day\s*\d+)(?:\s*[-:|]?\s*(.*))?$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (match != null) {
    final dayLabel = _capitalizeWords(match.group(1) ?? 'Day');
    final phaseLabel = _capitalizeWords(match.group(2) ?? 'Scheduled');
    return _TripTimelineSlot(
      dayLabel: dayLabel,
      phaseLabel: phaseLabel.trim().isEmpty ? 'Scheduled' : phaseLabel,
    );
  }

  return _TripTimelineSlot(
    dayLabel: 'Route stop',
    phaseLabel: _capitalizeWords(normalized),
  );
}

String _capitalizeWords(String raw) {
  return raw
      .split(RegExp(r'\\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
