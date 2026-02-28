import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_manual_edit_controller.dart';
import 'widgets/wishlist_manual_edit_basics_card.dart';
import 'widgets/wishlist_manual_edit_cities_section.dart';
import 'widgets/wishlist_manual_edit_time_windows_section.dart';

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
  final WishlistPlanManualEditController _controller =
      WishlistPlanManualEditController();

  @override
  void dispose() {
    _controller.dispose();
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
            onPressed: _controller.isSaving
                ? null
                : () {
                    final item = itemAsync.valueOrNull;
                    if (item != null) {
                      _save(item);
                    }
                  },
            icon: _controller.isSaving
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
          if (!_controller.didHydrate) {
            _controller.hydrate(
              item: item,
              planner: ref.read(geminiTripPlannerProvider),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: <Widget>[
              if (_controller.errorText != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _controller.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              WishlistManualEditBasicsCard(
                countryController: _controller.countryController,
                summaryController: _controller.summaryController,
                durationDaysController: _controller.durationDaysController,
                durationReasonController: _controller.durationReasonController,
                durationSource: _controller.durationSource,
                onDurationSourceChanged: (value) {
                  setState(() {
                    _controller.durationSource = value;
                    _controller.clearError();
                  });
                },
                onChanged: (_) {
                  setState(_controller.clearError);
                },
              ),
              const SizedBox(height: 12),
              WishlistManualEditTimeWindowsSection(
                timeWindows: _controller.timeWindows,
                onAdd: () async {
                  if (await _controller.addTimeWindow(context)) {
                    setState(() {});
                  }
                },
                onMove: (from, to) {
                  setState(() => _controller.moveWindow(from, to));
                },
                onEdit: (index) async {
                  if (await _controller.editTimeWindow(context, index)) {
                    setState(() {});
                  }
                },
                onDelete: (index) {
                  setState(() => _controller.deleteTimeWindow(index));
                },
              ),
              const SizedBox(height: 12),
              WishlistManualEditCitiesSection(
                cities: _controller.cities,
                onAddCity: () async {
                  if (await _controller.addCity(context)) {
                    setState(() {});
                  }
                },
                onErrorClear: () => setState(_controller.clearError),
                onMoveCity: (from, to) {
                  setState(() => _controller.moveCity(from, to));
                },
                onDeleteCity: (index) {
                  setState(() => _controller.deleteCity(index));
                },
                onAddTimelineStep: (city) async {
                  if (await _controller.addTimelineStep(context, city)) {
                    setState(() {});
                  }
                },
                onMoveTimelineStep: (city, from, to) {
                  setState(() => _controller.moveTimelineStep(city, from, to));
                },
                onEditTimelineStep: (city, index) async {
                  if (await _controller.editTimelineStep(context, city, index)) {
                    setState(() {});
                  }
                },
                onDeleteTimelineStep: (city, index) {
                  setState(() => _controller.deleteTimelineStep(city, index));
                },
                onAddThing: (city) async {
                  if (await _controller.addThing(context, city)) {
                    setState(() {});
                  }
                },
                onMoveThing: (city, from, to) {
                  setState(() => _controller.moveThing(city, from, to));
                },
                onEditThing: (city, index) async {
                  if (await _controller.editThing(context, city, index)) {
                    setState(() {});
                  }
                },
                onDeleteThing: (city, index) {
                  setState(() => _controller.deleteThing(city, index));
                },
                onCityStateChanged: () {
                  setState(_controller.clearError);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(WishlistItemRecord item) async {
    final validationError = _controller.validateDraft();
    if (validationError != null) {
      setState(() {
        _controller.errorText = validationError;
      });
      return;
    }

    final draftPlan = _controller.toDraftPlan();
    if (draftPlan == null) {
      setState(() {
        _controller.errorText = 'Failed to build plan from editor fields.';
      });
      return;
    }

    setState(() {
      _controller.isSaving = true;
      _controller.clearError();
    });

    try {
      final planner = ref.read(geminiTripPlannerProvider);
      final hydratedPlan = await planner.hydrateMissingCityImages(plan: draftPlan);

      final payload = <String, dynamic>{
        ...planner.toStorageJson(hydratedPlan),
        if (_controller.requestPayload != null) 'request': _controller.requestPayload,
      };
      final plannedCities = hydratedPlan.cityPlan
          .map((city) => city.city.trim())
          .where((city) => city.isNotEmpty)
          .join(', ');

      await ref.read(wishlistRepositoryProvider).updateWishlistItem(
            item.copyWith(
              countryName:
                  hydratedPlan.country.trim().isEmpty ? null : hydratedPlan.country.trim(),
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
        _controller.errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _controller.isSaving = false;
        });
      }
    }
  }
}
