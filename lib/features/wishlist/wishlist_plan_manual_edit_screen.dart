import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import 'gemini_trip_planner.dart';

class WishlistPlanManualEditScreen extends ConsumerStatefulWidget {
  const WishlistPlanManualEditScreen({
    super.key,
    required this.itemId,
  });

  final int itemId;

  @override
  ConsumerState<WishlistPlanManualEditScreen> createState() =>
      _WishlistPlanManualEditScreenState();
}

class _WishlistPlanManualEditScreenState
    extends ConsumerState<WishlistPlanManualEditScreen> {
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _durationDaysController = TextEditingController();
  final TextEditingController _durationReasonController =
      TextEditingController();

  bool _didHydrate = false;
  bool _isSaving = false;
  String? _errorText;
  String _durationSource = 'ai_recommended';

  int _nextId = 1;
  List<_EditableTimeWindow> _timeWindows = <_EditableTimeWindow>[];
  List<_EditableCity> _cities = <_EditableCity>[];
  Map<String, dynamic>? _requestPayload;

  @override
  void dispose() {
    _countryController.dispose();
    _summaryController.dispose();
    _durationDaysController.dispose();
    _durationReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(wishlistItemProvider(widget.itemId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Plan Edit'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _isSaving
                ? null
                : () {
                    final item = itemAsync.valueOrNull;
                    if (item == null) {
                      return;
                    }
                    _save(item);
                  },
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load item: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Wishlist item not found.'));
          }

          if (!_didHydrate) {
            _hydrate(item);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: <Widget>[
              if (_errorText != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Plan Basics',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _summaryController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Summary',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _durationDaysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration days',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _clearError(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _durationSource,
                              decoration: const InputDecoration(
                                labelText: 'Duration source',
                                border: OutlineInputBorder(),
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem<String>(
                                  value: 'ai_recommended',
                                  child: Text('AI recommended'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'user_selected',
                                  child: Text('User selected'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _durationSource = value;
                                  _errorText = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _durationReasonController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Duration reason',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _clearError(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _sectionHeader(
                context,
                title: 'Time Windows',
                onAdd: _addTimeWindow,
              ),
              const SizedBox(height: 8),
              if (_timeWindows.isEmpty)
                const _MutedHint(text: 'No time windows yet.')
              else
                ..._timeWindows.asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final window = entry.value;
                    return Card(
                      child: ListTile(
                        title: Text(window.label),
                        subtitle: Text('${window.months}\n${window.reason}'),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 2,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Move up',
                              onPressed: index == 0
                                  ? null
                                  : () => _moveWindow(index, index - 1),
                              icon: const Icon(Icons.keyboard_arrow_up),
                            ),
                            IconButton(
                              tooltip: 'Move down',
                              onPressed: index == _timeWindows.length - 1
                                  ? null
                                  : () => _moveWindow(index, index + 1),
                              icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _editTimeWindow(index),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _deleteTimeWindow(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              _sectionHeader(
                context,
                title: 'City Sections',
                onAdd: _addCity,
              ),
              const SizedBox(height: 8),
              if (_cities.isEmpty)
                const _MutedHint(text: 'No cities yet.')
              else
                ..._cities.asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final city = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    city.city.trim().isEmpty
                                        ? 'Untitled city'
                                        : city.city,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move up',
                                  onPressed: index == 0
                                      ? null
                                      : () => _moveCity(index, index - 1),
                                  icon: const Icon(Icons.keyboard_arrow_up),
                                ),
                                IconButton(
                                  tooltip: 'Move down',
                                  onPressed: index == _cities.length - 1
                                      ? null
                                      : () => _moveCity(index, index + 1),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                ),
                                IconButton(
                                  tooltip: 'Delete city',
                                  onPressed: () => _deleteCity(index),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: city.city,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                city.city = value;
                                _clearError();
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextFormField(
                                    initialValue: city.days.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Days',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      city.days = int.tryParse(value.trim()) ??
                                          city.days;
                                      _clearError();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SwitchListTile(
                                    value: city.isExtra,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Extra city'),
                                    onChanged: (value) {
                                      setState(() {
                                        city.isExtra = value;
                                        _errorText = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: city.reason,
                              decoration: const InputDecoration(
                                labelText: 'Reason',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                city.reason = value;
                                _clearError();
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: city.overview,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Overview',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                city.overview = value;
                                _clearError();
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: city.imageQuery,
                              decoration: const InputDecoration(
                                labelText: 'Image query',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                city.imageQuery = value;
                                _clearError();
                              },
                            ),
                            if (city.image != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Current image: ${city.image!.source} | ${city.image!.license}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            const SizedBox(height: 10),
                            _subSectionHeader(
                              context,
                              title: 'Timeline',
                              onAdd: () => _addTimelineStep(city),
                            ),
                            const SizedBox(height: 6),
                            if (city.timeline.isEmpty)
                              const _MutedHint(
                                  text: 'No timeline steps for this city.'),
                            ...city.timeline.asMap().entries.map(
                              (timelineEntry) {
                                final timelineIndex = timelineEntry.key;
                                final timeline = timelineEntry.value;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      '${timeline.slot} · ${timeline.place}'),
                                  subtitle: Text(timeline.note),
                                  trailing: Wrap(
                                    spacing: 2,
                                    children: <Widget>[
                                      IconButton(
                                        tooltip: 'Move up',
                                        onPressed: timelineIndex == 0
                                            ? null
                                            : () => _moveTimelineStep(
                                                  city,
                                                  timelineIndex,
                                                  timelineIndex - 1,
                                                ),
                                        icon:
                                            const Icon(Icons.keyboard_arrow_up),
                                      ),
                                      IconButton(
                                        tooltip: 'Move down',
                                        onPressed: timelineIndex ==
                                                city.timeline.length - 1
                                            ? null
                                            : () => _moveTimelineStep(
                                                  city,
                                                  timelineIndex,
                                                  timelineIndex + 1,
                                                ),
                                        icon: const Icon(
                                            Icons.keyboard_arrow_down),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed: () => _editTimelineStep(
                                            city, timelineIndex),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        onPressed: () => _deleteTimelineStep(
                                            city, timelineIndex),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            _subSectionHeader(
                              context,
                              title: 'Things to Do',
                              onAdd: () => _addThing(city),
                            ),
                            const SizedBox(height: 6),
                            if (city.thingsToDo.isEmpty)
                              const _MutedHint(
                                  text: 'No activity items for this city.'),
                            ...city.thingsToDo.asMap().entries.map(
                              (thingEntry) {
                                final thingIndex = thingEntry.key;
                                final thing = thingEntry.value;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(thing.value),
                                  trailing: Wrap(
                                    spacing: 2,
                                    children: <Widget>[
                                      IconButton(
                                        tooltip: 'Move up',
                                        onPressed: thingIndex == 0
                                            ? null
                                            : () => _moveThing(
                                                  city,
                                                  thingIndex,
                                                  thingIndex - 1,
                                                ),
                                        icon:
                                            const Icon(Icons.keyboard_arrow_up),
                                      ),
                                      IconButton(
                                        tooltip: 'Move down',
                                        onPressed: thingIndex ==
                                                city.thingsToDo.length - 1
                                            ? null
                                            : () => _moveThing(
                                                  city,
                                                  thingIndex,
                                                  thingIndex + 1,
                                                ),
                                        icon: const Icon(
                                            Icons.keyboard_arrow_down),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed: () =>
                                            _editThing(city, thingIndex),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        onPressed: () =>
                                            _deleteThing(city, thingIndex),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }

  Widget _subSectionHeader(
    BuildContext context, {
    required String title,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }

  void _hydrate(WishlistItemRecord item) {
    final planner = ref.read(geminiTripPlannerProvider);
    final parsedPlan = planner.parseStoredPlan(
      item.aiPlan ?? '',
      fallbackCountry: item.countryName ?? '',
    );

    final seedPlan = parsedPlan ??
        GeminiTripPlan(
          country: item.countryName ?? '',
          summary: '',
          stayDuration: null,
          timeWindows: const <GeminiTimeWindow>[],
          cityPlan: const <GeminiCityPlan>[],
          cityDetails: const <GeminiCityDetail>[],
          rawText: '',
        );

    _countryController.text = seedPlan.country;
    _summaryController.text = seedPlan.summary;
    _durationDaysController.text = seedPlan.stayDuration?.days.toString() ?? '';
    _durationReasonController.text = seedPlan.stayDuration?.reason ?? '';
    _durationSource = seedPlan.stayDuration?.source == 'user_selected'
        ? 'user_selected'
        : 'ai_recommended';

    _timeWindows = seedPlan.timeWindows
        .map(
          (window) => _EditableTimeWindow(
            id: _allocateId(),
            label: window.label,
            months: window.months,
            reason: window.reason,
          ),
        )
        .toList(growable: true);

    final detailByCity = <String, GeminiCityDetail>{
      for (final detail in seedPlan.cityDetails) _cityKey(detail.city): detail,
    };

    _cities = seedPlan.cityPlan.map(
      (city) {
        final detail = detailByCity[_cityKey(city.city)];
        return _EditableCity(
          id: _allocateId(),
          originalCityKey: _cityKey(city.city),
          originalImageQuery: detail?.imageQuery ?? '${city.city} skyline',
          city: city.city,
          days: city.days,
          reason: city.reason,
          isExtra: city.isExtra,
          overview: detail?.overview ?? '',
          imageQuery: detail?.imageQuery ?? '${city.city} skyline',
          image: detail?.image,
          timeline: detail?.timeline
                  .map(
                    (step) => _EditableTimeline(
                      id: _allocateId(),
                      slot: step.slot,
                      place: step.place,
                      note: step.note,
                    ),
                  )
                  .toList(growable: true) ??
              <_EditableTimeline>[],
          thingsToDo: detail?.thingsToDo
                  .map(
                    (thing) => _EditableThing(
                      id: _allocateId(),
                      value: thing,
                    ),
                  )
                  .toList(growable: true) ??
              <_EditableThing>[],
        );
      },
    ).toList(growable: true);

    _requestPayload = _readRequestPayload(item.aiPlan);
    _didHydrate = true;
  }

  Map<String, dynamic>? _readRequestPayload(String? rawPlan) {
    final raw = rawPlan?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final request = decoded['request'];
      if (request is! Map<String, dynamic>) {
        return null;
      }
      return Map<String, dynamic>.from(request);
    } catch (_) {
      return null;
    }
  }

  int _allocateId() {
    final id = _nextId;
    _nextId += 1;
    return id;
  }

  Future<void> _addTimeWindow() async {
    final created = await _showTimeWindowDialog();
    if (created == null) {
      return;
    }
    setState(() {
      _timeWindows.add(created);
      _errorText = null;
    });
  }

  Future<void> _editTimeWindow(int index) async {
    final updated = await _showTimeWindowDialog(existing: _timeWindows[index]);
    if (updated == null) {
      return;
    }
    setState(() {
      _timeWindows[index] = updated.copyWith(id: _timeWindows[index].id);
      _errorText = null;
    });
  }

  void _deleteTimeWindow(int index) {
    setState(() {
      _timeWindows.removeAt(index);
      _errorText = null;
    });
  }

  void _moveWindow(int from, int to) {
    setState(() {
      final item = _timeWindows.removeAt(from);
      _timeWindows.insert(to, item);
      _errorText = null;
    });
  }

  Future<void> _addCity() async {
    final city = await _showCityDialog();
    if (city == null) {
      return;
    }
    setState(() {
      _cities.add(city);
      _errorText = null;
    });
  }

  void _deleteCity(int index) {
    setState(() {
      _cities.removeAt(index);
      _errorText = null;
    });
  }

  void _moveCity(int from, int to) {
    setState(() {
      final city = _cities.removeAt(from);
      _cities.insert(to, city);
      _errorText = null;
    });
  }

  Future<void> _addTimelineStep(_EditableCity city) async {
    final created = await _showTimelineDialog();
    if (created == null) {
      return;
    }
    setState(() {
      city.timeline.add(created);
      _errorText = null;
    });
  }

  Future<void> _editTimelineStep(_EditableCity city, int index) async {
    final updated = await _showTimelineDialog(existing: city.timeline[index]);
    if (updated == null) {
      return;
    }
    setState(() {
      city.timeline[index] = updated.copyWith(id: city.timeline[index].id);
      _errorText = null;
    });
  }

  void _deleteTimelineStep(_EditableCity city, int index) {
    setState(() {
      city.timeline.removeAt(index);
      _errorText = null;
    });
  }

  void _moveTimelineStep(_EditableCity city, int from, int to) {
    setState(() {
      final item = city.timeline.removeAt(from);
      city.timeline.insert(to, item);
      _errorText = null;
    });
  }

  Future<void> _addThing(_EditableCity city) async {
    final created = await _showThingDialog();
    if (created == null) {
      return;
    }
    setState(() {
      city.thingsToDo.add(created);
      _errorText = null;
    });
  }

  Future<void> _editThing(_EditableCity city, int index) async {
    final updated = await _showThingDialog(existing: city.thingsToDo[index]);
    if (updated == null) {
      return;
    }
    setState(() {
      city.thingsToDo[index] = updated.copyWith(id: city.thingsToDo[index].id);
      _errorText = null;
    });
  }

  void _deleteThing(_EditableCity city, int index) {
    setState(() {
      city.thingsToDo.removeAt(index);
      _errorText = null;
    });
  }

  void _moveThing(_EditableCity city, int from, int to) {
    setState(() {
      final item = city.thingsToDo.removeAt(from);
      city.thingsToDo.insert(to, item);
      _errorText = null;
    });
  }

  Future<_EditableTimeWindow?> _showTimeWindowDialog({
    _EditableTimeWindow? existing,
  }) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final monthsController =
        TextEditingController(text: existing?.months ?? '');
    final reasonController =
        TextEditingController(text: existing?.reason ?? '');

    final result = await showDialog<_EditableTimeWindow>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              Text(existing == null ? 'Add Time Window' : 'Edit Time Window'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: monthsController,
                  decoration: const InputDecoration(
                    labelText: 'Months',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final label = labelController.text.trim();
                final months = monthsController.text.trim();
                final reason = reasonController.text.trim();
                if (label.isEmpty || months.isEmpty || reason.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _EditableTimeWindow(
                    id: existing?.id ?? _allocateId(),
                    label: label,
                    months: months,
                    reason: reason,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    labelController.dispose();
    monthsController.dispose();
    reasonController.dispose();
    return result;
  }

  Future<_EditableCity?> _showCityDialog() async {
    final cityController = TextEditingController();
    final daysController = TextEditingController(text: '2');
    final reasonController = TextEditingController();

    final result = await showDialog<_EditableCity>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add City'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Days',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final city = cityController.text.trim();
                final days = int.tryParse(daysController.text.trim());
                final reason = reasonController.text.trim();
                if (city.isEmpty ||
                    days == null ||
                    days <= 0 ||
                    reason.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _EditableCity(
                    id: _allocateId(),
                    originalCityKey: null,
                    originalImageQuery: '$city skyline',
                    city: city,
                    days: days,
                    reason: reason,
                    isExtra: false,
                    overview: '',
                    imageQuery: '$city skyline',
                    timeline: <_EditableTimeline>[],
                    thingsToDo: <_EditableThing>[],
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    cityController.dispose();
    daysController.dispose();
    reasonController.dispose();
    return result;
  }

  Future<_EditableTimeline?> _showTimelineDialog({
    _EditableTimeline? existing,
  }) async {
    final slotController = TextEditingController(text: existing?.slot ?? '');
    final placeController = TextEditingController(text: existing?.place ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');

    final result = await showDialog<_EditableTimeline>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
              existing == null ? 'Add Timeline Step' : 'Edit Timeline Step'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: slotController,
                  decoration: const InputDecoration(
                    labelText: 'Day/slot',
                    hintText: 'Day 1 AM',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: placeController,
                  decoration: const InputDecoration(
                    labelText: 'Place',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final slot = slotController.text.trim();
                final place = placeController.text.trim();
                final note = noteController.text.trim();
                if (slot.isEmpty || place.isEmpty || note.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _EditableTimeline(
                    id: existing?.id ?? _allocateId(),
                    slot: slot,
                    place: place,
                    note: note,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    slotController.dispose();
    placeController.dispose();
    noteController.dispose();
    return result;
  }

  Future<_EditableThing?> _showThingDialog({
    _EditableThing? existing,
  }) async {
    final valueController = TextEditingController(text: existing?.value ?? '');

    final result = await showDialog<_EditableThing>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Activity' : 'Edit Activity'),
          content: TextField(
            controller: valueController,
            decoration: const InputDecoration(
              labelText: 'Activity',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = valueController.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _EditableThing(
                    id: existing?.id ?? _allocateId(),
                    value: value,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    valueController.dispose();
    return result;
  }

  Future<void> _save(WishlistItemRecord item) async {
    final validationError = _validateDraft();
    if (validationError != null) {
      setState(() {
        _errorText = validationError;
      });
      return;
    }

    final draftPlan = _toDraftPlan();
    if (draftPlan == null) {
      setState(() {
        _errorText = 'Failed to build plan from editor fields.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final planner = ref.read(geminiTripPlannerProvider);
      final hydratedPlan =
          await planner.hydrateMissingCityImages(plan: draftPlan);

      final payload = <String, dynamic>{
        ...planner.toStorageJson(hydratedPlan),
        if (_requestPayload != null) 'request': _requestPayload,
      };

      final plannedCities = hydratedPlan.cityPlan
          .map((city) => city.city.trim())
          .where((city) => city.isNotEmpty)
          .join(', ');

      await ref.read(wishlistRepositoryProvider).updateWishlistItem(
            item.copyWith(
              countryName: hydratedPlan.country.trim().isEmpty
                  ? null
                  : hydratedPlan.country.trim(),
              plannedCities: plannedCities.isEmpty ? null : plannedCities,
              aiPlan: jsonEncode(payload),
            ),
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual plan changes saved.')),
      );
      context.pop();
    } catch (error) {
      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateDraft() {
    final country = _countryController.text.trim();
    final summary = _summaryController.text.trim();
    if (country.isEmpty) {
      return 'Country is required.';
    }
    if (summary.isEmpty) {
      return 'Summary is required.';
    }

    final durationRaw = _durationDaysController.text.trim();
    if (durationRaw.isNotEmpty) {
      final days = int.tryParse(durationRaw);
      if (days == null || days <= 0) {
        return 'Duration days must be a positive number.';
      }
    }

    for (final city in _cities) {
      if (city.city.trim().isEmpty) {
        return 'Each city must have a name.';
      }
      if (city.days <= 0) {
        return 'City days must be positive for ${city.city.trim()}.';
      }
      if (city.reason.trim().isEmpty) {
        return 'Each city must have a reason (${city.city.trim()}).';
      }
      for (final step in city.timeline) {
        if (step.slot.trim().isEmpty ||
            step.place.trim().isEmpty ||
            step.note.trim().isEmpty) {
          return 'Timeline entries must include day/slot, place, and note.';
        }
      }
      for (final thing in city.thingsToDo) {
        if (thing.value.trim().isEmpty) {
          return 'Things-to-do entries cannot be empty.';
        }
      }
    }

    return null;
  }

  GeminiTripPlan? _toDraftPlan() {
    final country = _countryController.text.trim();
    final summary = _summaryController.text.trim();
    if (country.isEmpty || summary.isEmpty) {
      return null;
    }

    final durationDays = int.tryParse(_durationDaysController.text.trim());
    final durationReason = _durationReasonController.text.trim();
    final duration = durationDays == null
        ? null
        : GeminiStayDuration(
            days: durationDays.clamp(1, 45),
            reason: durationReason.isEmpty
                ? 'Manual duration updated by user.'
                : durationReason,
            source: _durationSource == 'user_selected'
                ? 'user_selected'
                : 'ai_recommended',
          );

    final windows = _timeWindows
        .map(
          (window) => GeminiTimeWindow(
            label: window.label.trim(),
            months: window.months.trim(),
            reason: window.reason.trim(),
          ),
        )
        .where(
          (window) =>
              window.label.isNotEmpty &&
              window.months.isNotEmpty &&
              window.reason.isNotEmpty,
        )
        .toList(growable: false);

    final cityPlan = <GeminiCityPlan>[];
    final cityDetails = <GeminiCityDetail>[];

    for (final city in _cities) {
      final cityName = city.city.trim();
      if (cityName.isEmpty) {
        continue;
      }

      final keepExistingImage = city.originalCityKey != null &&
          city.originalCityKey == _cityKey(cityName) &&
          city.image != null &&
          city.originalImageQuery == city.imageQuery.trim();

      cityPlan.add(
        GeminiCityPlan(
          city: cityName,
          days: city.days.clamp(1, 45),
          reason: city.reason.trim(),
          isExtra: city.isExtra,
        ),
      );

      cityDetails.add(
        GeminiCityDetail(
          city: cityName,
          overview: city.overview.trim(),
          imageQuery: city.imageQuery.trim().isEmpty
              ? '$cityName skyline'
              : city.imageQuery.trim(),
          timeline: city.timeline
              .map(
                (step) => GeminiTimelineStop(
                  slot: step.slot.trim(),
                  place: step.place.trim(),
                  note: step.note.trim(),
                ),
              )
              .where(
                (step) =>
                    step.slot.isNotEmpty &&
                    step.place.isNotEmpty &&
                    step.note.isNotEmpty,
              )
              .toList(growable: false),
          thingsToDo: city.thingsToDo
              .map((item) => item.value.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
          image: keepExistingImage ? city.image : null,
        ),
      );
    }

    return GeminiTripPlan(
      country: country,
      summary: summary,
      stayDuration: duration,
      timeWindows: windows,
      cityPlan: cityPlan,
      cityDetails: cityDetails,
      rawText: '',
    );
  }

  void _clearError() {
    if (_errorText == null) {
      return;
    }
    setState(() {
      _errorText = null;
    });
  }
}

class _MutedHint extends StatelessWidget {
  const _MutedHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _EditableTimeWindow {
  const _EditableTimeWindow({
    required this.id,
    required this.label,
    required this.months,
    required this.reason,
  });

  final int id;
  final String label;
  final String months;
  final String reason;

  _EditableTimeWindow copyWith({
    int? id,
    String? label,
    String? months,
    String? reason,
  }) {
    return _EditableTimeWindow(
      id: id ?? this.id,
      label: label ?? this.label,
      months: months ?? this.months,
      reason: reason ?? this.reason,
    );
  }
}

class _EditableCity {
  _EditableCity({
    required this.id,
    required this.originalCityKey,
    required this.originalImageQuery,
    required this.city,
    required this.days,
    required this.reason,
    required this.isExtra,
    required this.overview,
    required this.imageQuery,
    required this.timeline,
    required this.thingsToDo,
    this.image,
  });

  final int id;
  final String? originalCityKey;
  final String originalImageQuery;
  String city;
  int days;
  String reason;
  bool isExtra;
  String overview;
  String imageQuery;
  List<_EditableTimeline> timeline;
  List<_EditableThing> thingsToDo;
  GeminiCityImage? image;
}

class _EditableTimeline {
  const _EditableTimeline({
    required this.id,
    required this.slot,
    required this.place,
    required this.note,
  });

  final int id;
  final String slot;
  final String place;
  final String note;

  _EditableTimeline copyWith({
    int? id,
    String? slot,
    String? place,
    String? note,
  }) {
    return _EditableTimeline(
      id: id ?? this.id,
      slot: slot ?? this.slot,
      place: place ?? this.place,
      note: note ?? this.note,
    );
  }
}

class _EditableThing {
  const _EditableThing({
    required this.id,
    required this.value,
  });

  final int id;
  final String value;

  _EditableThing copyWith({
    int? id,
    String? value,
  }) {
    return _EditableThing(
      id: id ?? this.id,
      value: value ?? this.value,
    );
  }
}

String _cityKey(String value) => value.trim().toLowerCase();
