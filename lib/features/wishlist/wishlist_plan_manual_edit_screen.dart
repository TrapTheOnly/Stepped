import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../social/social_state.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_manual_edit_controller.dart';
import 'wishlist_plan_manual_edit_city_screen.dart';
import 'wishlist_plan_ui_state.dart';
import 'widgets/wishlist_editor_shell.dart';
import 'widgets/wishlist_editorial_widgets.dart';
import 'widgets/wishlist_manual_edit_basics_card.dart';
import 'widgets/wishlist_manual_edit_cities_section.dart';
import 'widgets/wishlist_manual_edit_time_windows_section.dart';
import '../trips/widgets/add_trip_cover_image_preview.dart';

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
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: wishlistEditorInputDecorationTheme(context),
      ),
      child: WishlistEditorShell(
        title: 'Manual Edit',
        onBack: () => context.pop(),
        topActions: <Widget>[
          WishlistEditorTopBarIconAction(
            icon: Icons.save_outlined,
            isLoading: _controller.isSaving,
            onTap: itemAsync.valueOrNull == null || _controller.isSaving
                ? null
                : () => _save(itemAsync.valueOrNull!),
          ),
        ],
        body: itemAsync.when(
          loading: () => const WishlistEditorStatusView(
            title: 'Opening manual editor',
            message: 'Loading the itinerary draft and editable city details.',
            showProgress: true,
          ),
          error: (error, _) => WishlistEditorStatusView(
            title: 'Editor unavailable',
            message: 'Failed to load item: $error',
          ),
          data: (item) {
            if (item == null) {
              return const WishlistEditorStatusView(
                title: 'Wishlist item not found',
                message: 'This wishlist idea is no longer available.',
              );
            }
            if (!_controller.didHydrate) {
              _controller.hydrate(
                item: item,
                planner: ref.read(geminiTripPlannerProvider),
              );
            }

            return ListView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                16,
                wishlistEditorTopOverlayClearance,
                16,
                wishlistEditorBottomDockClearance + 48,
              ),
              children: <Widget>[
                WishlistEditorHeroCard(
                  title: item.title,
                  badge: 'Manual editor',
                  subtitle: _controller.countryController.text.trim().isEmpty
                      ? 'Build the route, timing windows, and city cards by hand.'
                      : _controller.countryController.text.trim(),
                  imageUrl: _controller.coverImage?.imageUrl ??
                      wishlistPrimaryImageUrl(item),
                  chips: <String>[
                    if (_controller.durationDaysController.text
                        .trim()
                        .isNotEmpty)
                      '${_controller.durationDaysController.text.trim()} days',
                    if (_controller.cities.isNotEmpty)
                      '${_controller.cities.length} cities',
                  ],
                ),
                const SizedBox(height: 18),
                WishlistEditorSectionCard(
                  title: 'Cover image',
                  subtitle:
                      'Keep the AI image or upload your own cover for this wishlist idea.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickCoverImageFromDevice,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Upload image'),
                            ),
                          ),
                        ],
                      ),
                      if (_controller.coverImage?.imageUrl.trim().isNotEmpty ??
                          false) ...<Widget>[
                        const SizedBox(height: 12),
                        AddTripCoverImagePreview(
                          uri: _controller.coverImage!.imageUrl.trim(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_controller.errorText != null) ...<Widget>[
                  WishlistEditorSectionCard(
                    title: 'Something needs attention',
                    child: Text(
                      _controller.errorText!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                WishlistManualEditBasicsCard(
                  countryController: _controller.countryController,
                  summaryController: _controller.summaryController,
                  durationDaysController: _controller.durationDaysController,
                  durationReasonController:
                      _controller.durationReasonController,
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
                  onOpenCity: (index) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WishlistPlanManualEditCityScreen(
                          city: _controller.cities[index],
                          controller: _controller,
                          onDraftChanged: () {
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    );
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  onMoveCity: (from, to) {
                    setState(() => _controller.moveCity(from, to));
                  },
                  onDeleteCity: (index) {
                    setState(() => _controller.deleteCity(index));
                  },
                ),
              ],
            );
          },
        ),
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
      final hydratedPlan =
          await planner.hydrateMissingCityImages(plan: draftPlan);

      final payload = <String, dynamic>{
        ...planner.toStorageJson(hydratedPlan),
        if (_controller.requestPayload != null)
          'request': _controller.requestPayload,
      };
      final mergedPayload = mergeWishlistPlanUiState(
        payload: payload,
        existingRawPlan: item.aiPlan,
      );
      if (_controller.coverImage != null) {
        mergedPayload['cover_image'] = <String, dynamic>{
          'image_url': _controller.coverImage!.imageUrl,
          'source_page_url': _controller.coverImage!.sourcePageUrl,
          'title': _controller.coverImage!.title,
          'creator': _controller.coverImage!.creator,
          'license': _controller.coverImage!.license,
          'license_url': _controller.coverImage!.licenseUrl,
          'source': _controller.coverImage!.source,
        };
      }
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
              aiPlan: jsonEncode(mergedPayload),
            ),
          );
      await ref.read(socialSyncControllerProvider).flushWishlistNow();
      ref.invalidate(wishlistItemProvider(widget.itemId));
      ref.invalidate(wishlistStreamProvider);

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

    setState(() {
      _controller.setCoverImageUri(path.trim());
    });
  }
}
