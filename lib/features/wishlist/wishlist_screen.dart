import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/frosted_squircle.dart';
import '../../widgets/stepped_top_bar.dart';
import '../map/globe/globe_country_data.dart';
import '../map/map_viewmodel.dart';
import '../settings/app_preferences.dart';
import 'widgets/wishlist_editorial_widgets.dart';

const _wishlistBottomNavClearance = 112.0;
const _wishlistFabOffset = 121.0;
const _wishlistTopOverlayClearance = 114.0;

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  final DateFormat _dateFormat = DateFormat.yMMMd();
  PersistentBottomSheetController? _actionsSheetController;

  @override
  Widget build(BuildContext context) {
    return _buildScreenContent(context);
  }

  @override
  void dispose() {
    _actionsSheetController?.close();
    super.dispose();
  }
}

class _WishlistEditorResult {
  const _WishlistEditorResult({
    required this.title,
    required this.countryName,
    required this.countryCode,
    required this.plannedCities,
    required this.plannedStartDate,
    required this.plannedEndDate,
    required this.openPlannerAfterSave,
  });

  final String title;
  final String? countryName;
  final String? countryCode;
  final String? plannedCities;
  final int? plannedStartDate;
  final int? plannedEndDate;
  final bool openPlannerAfterSave;
}

enum _WishlistAction {
  plan,
  setDates,
  edit,
  delete,
}

String _normalizeCountryName(String raw) {
  return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

extension _WishlistScreenBuildMethods on _WishlistScreenState {
  Widget _buildScreenContent(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistStreamProvider);
    final preferences = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;
    final dataset = ref.watch(globeCountryDatasetProvider).valueOrNull;
    final countryCodeByName = _countryCodeByName(dataset);
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(
            child: IgnorePointer(
              child: WishlistAtmosphere(),
            ),
          ),
          Positioned.fill(
            child: wishlistAsync.when(
              loading: () => const WishlistScrollView(
                bottomPadding: _wishlistBottomNavClearance + 44,
                children: <Widget>[
                  SizedBox(height: _wishlistTopOverlayClearance),
                  WishlistHorizontalPadding(
                    child: WishlistHeader(),
                  ),
                  SizedBox(height: 28),
                  WishlistHorizontalPadding(
                    child: WishlistStatusCard(
                      title: 'Loading your saved horizons',
                      message:
                          'Gathering the destinations you want to turn into trips.',
                      showProgress: true,
                    ),
                  ),
                ],
              ),
              error: (error, _) => WishlistScrollView(
                bottomPadding: _wishlistBottomNavClearance + 44,
                children: <Widget>[
                  const SizedBox(height: _wishlistTopOverlayClearance),
                  const WishlistHorizontalPadding(
                    child: WishlistHeader(),
                  ),
                  const SizedBox(height: 28),
                  WishlistHorizontalPadding(
                    child: WishlistStatusCard(
                      title: 'Wishlist unavailable',
                      message: 'Failed to load wishlist: $error',
                    ),
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const WishlistScrollView(
                    bottomPadding: _wishlistBottomNavClearance + 44,
                    children: <Widget>[
                      SizedBox(height: _wishlistTopOverlayClearance),
                      WishlistHorizontalPadding(
                        child: WishlistHeader(),
                      ),
                      SizedBox(height: 28),
                      WishlistHorizontalPadding(
                        child: WishlistEmptyState(),
                      ),
                    ],
                  );
                }

                return WishlistScrollView(
                  bottomPadding: _wishlistBottomNavClearance + 44,
                  children: <Widget>[
                    const SizedBox(height: _wishlistTopOverlayClearance),
                    const WishlistHorizontalPadding(
                      child: WishlistHeader(),
                    ),
                    const SizedBox(height: 28),
                    for (final item in items) ...<Widget>[
                      WishlistHorizontalPadding(
                        child: WishlistStoryCard(
                          item: item,
                          countryCode: _countryCodeFor(
                            item,
                            countryCodeByName,
                          ),
                          showDate: preferences.showWishlistDates,
                          dateFormat: _dateFormat,
                          onOpenPlan: item.id == null
                              ? null
                              : () => context.push('/wishlist/plan/${item.id}'),
                          onPinToggle: () => _togglePinned(item),
                          onActions: () => _showActions(
                            item: item,
                            countryCodeByName: countryCodeByName,
                            requireDeleteConfirmation:
                                preferences.confirmWishlistDelete,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SteppedTopBar(
                  onOpenSettings: () => context.push('/profile/settings'),
                  onOpenProfile: () => context.push('/profile'),
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: _wishlistFabOffset,
            child: WishlistAddIdeaButton(
              onTap: () => context.push('/wishlist/add'),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _countryCodeByName(GlobeCountryDataset? dataset) {
    if (dataset == null) {
      return const <String, String>{};
    }
    return {
      for (final country in dataset.countries)
        _normalizeCountryName(country.name): country.iso2.toUpperCase(),
    };
  }

  String? _countryCodeFor(
    WishlistItemRecord item,
    Map<String, String> countryCodeByName,
  ) {
    final explicit = item.countryCode?.trim().toUpperCase();
    if (explicit != null && explicit.length == 2) {
      return explicit;
    }
    final name = item.countryName?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    return countryCodeByName[_normalizeCountryName(name)];
  }

  Future<void> _togglePinned(WishlistItemRecord item) async {
    final id = item.id;
    if (id == null) {
      return;
    }

    final willPin = !item.isPinned;
    await ref.read(wishlistRepositoryProvider).setPinnedState(
          id: id,
          isPinned: willPin,
        );

    if (!mounted) {
      return;
    }
  }

  Future<void> _showActions({
    required WishlistItemRecord item,
    required Map<String, String> countryCodeByName,
    required bool requireDeleteConfirmation,
  }) async {
    _actionsSheetController?.close();
    _actionsSheetController = null;

    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState == null) {
      return;
    }

    final completer = Completer<_WishlistAction?>();
    late PersistentBottomSheetController controller;

    void completeWith(_WishlistAction? action) {
      if (!completer.isCompleted) {
        completer.complete(action);
      }
      controller.close();
    }

    controller = scaffoldState.showBottomSheet(
      (sheetContext) {
        return _WishlistActionsSheet(
          item: item,
          onOpenPlan:
              item.id == null ? null : () => completeWith(_WishlistAction.plan),
          onPinToggle: () {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
            controller.close();
            _togglePinned(item);
          },
          onSetDates: () => completeWith(_WishlistAction.setDates),
          onEdit: () => completeWith(_WishlistAction.edit),
          onDelete: () => completeWith(_WishlistAction.delete),
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      showDragHandle: false,
    );
    _actionsSheetController = controller;
    controller.closed.whenComplete(() {
      if (identical(_actionsSheetController, controller)) {
        _actionsSheetController = null;
      }
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    final action = await completer.future;

    if (action == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    switch (action) {
      case _WishlistAction.plan:
        if (item.id != null) {
          context.push('/wishlist/plan/${item.id}');
        }
        return;
      case _WishlistAction.setDates:
        await _showEditor(
          existing: item,
          countryCodeByName: countryCodeByName,
        );
        return;
      case _WishlistAction.edit:
        await _showEditor(
          existing: item,
          countryCodeByName: countryCodeByName,
        );
        return;
      case _WishlistAction.delete:
        await _deleteItem(
          item: item,
          requireConfirmation: requireDeleteConfirmation,
        );
        return;
    }
  }
}

class _WishlistActionsSheet extends StatelessWidget {
  const _WishlistActionsSheet({
    required this.item,
    required this.onPinToggle,
    required this.onSetDates,
    required this.onEdit,
    required this.onDelete,
    this.onOpenPlan,
  });

  final WishlistItemRecord item;
  final VoidCallback? onOpenPlan;
  final VoidCallback onPinToggle;
  final VoidCallback onSetDates;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FrostedSquircle(
        radius: 34,
        blurSigma: 20,
        color: colorScheme.surface.withValues(alpha: 0.66),
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.16),
        shadowColor: colorScheme.primary.withValues(alpha: 0.12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  shape: squircleShape(8),
                ),
                child: const SizedBox(width: 36, height: 4),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Open plan'),
                subtitle: const Text('Review, regenerate, or manually edit'),
                enabled: onOpenPlan != null,
                onTap: onOpenPlan,
              ),
              ListTile(
                leading: Icon(
                  item.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                ),
                title: Text(item.isPinned ? 'Unpin from top' : 'Pin to top'),
                onTap: onPinToggle,
              ),
              ListTile(
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('Set dates'),
                subtitle: const Text('Add exact travel dates to this wishlist'),
                onTap: onSetDates,
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: onEdit,
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _WishlistScreenActionMethods on _WishlistScreenState {
  Future<void> _showEditor({
    required Map<String, String> countryCodeByName,
    WishlistItemRecord? existing,
  }) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final countryController =
        TextEditingController(text: existing?.countryName ?? '');
    final citiesController =
        TextEditingController(text: existing?.plannedCities ?? '');
    DateTimeRange? dateRange;
    if (existing?.plannedStartDate != null &&
        existing?.plannedEndDate != null) {
      dateRange = DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(existing!.plannedStartDate!),
        end: DateTime.fromMillisecondsSinceEpoch(existing.plannedEndDate!),
      );
    }
    var openPlannerAfterSave = false;

    final result = await showDialog<_WishlistEditorResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickDateRange() async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
                initialDateRange: dateRange ??
                    DateTimeRange(
                      start: now,
                      end: now.add(const Duration(days: 6)),
                    ),
              );
              if (picked == null) {
                return;
              }
              setState(() {
                dateRange = picked;
              });
            }

            return AlertDialog(
              title: Text(existing == null ? 'Add Wishlist Idea' : 'Edit Idea'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: countryController,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        hintText: 'Optional but recommended for AI planning',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: citiesController,
                      decoration: const InputDecoration(
                        labelText: 'Potential cities',
                        hintText: 'Tokyo, Kyoto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.date_range_outlined),
                      title: Text(
                        dateRange == null
                            ? 'No date window selected'
                            : '${_dateFormat.format(dateRange!.start)} - ${_dateFormat.format(dateRange!.end)}',
                      ),
                      trailing: TextButton(
                        onPressed: pickDateRange,
                        child: Text(dateRange == null ? 'Select' : 'Change'),
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
                TextButton.icon(
                  onPressed: () {
                    openPlannerAfterSave = true;
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      return;
                    }
                    final country = _optional(countryController.text);
                    Navigator.of(dialogContext).pop(
                      _WishlistEditorResult(
                        title: title,
                        countryName: country,
                        countryCode: country == null
                            ? null
                            : countryCodeByName[_normalizeCountryName(country)],
                        plannedCities: _optional(citiesController.text),
                        plannedStartDate:
                            dateRange?.start.millisecondsSinceEpoch,
                        plannedEndDate: dateRange?.end.millisecondsSinceEpoch,
                        openPlannerAfterSave: true,
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Save + Open Plan'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      return;
                    }
                    final country = _optional(countryController.text);
                    Navigator.of(dialogContext).pop(
                      _WishlistEditorResult(
                        title: title,
                        countryName: country,
                        countryCode: country == null
                            ? null
                            : countryCodeByName[_normalizeCountryName(country)],
                        plannedCities: _optional(citiesController.text),
                        plannedStartDate:
                            dateRange?.start.millisecondsSinceEpoch,
                        plannedEndDate: dateRange?.end.millisecondsSinceEpoch,
                        openPlannerAfterSave: openPlannerAfterSave,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    countryController.dispose();
    citiesController.dispose();

    if (result == null) {
      return;
    }

    final repository = ref.read(wishlistRepositoryProvider);
    if (existing == null) {
      final insertedId = await repository.addWishlistItem(
        WishlistItemRecord(
          title: result.title,
          countryName: result.countryName,
          countryCode: result.countryCode,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          plannedCities: result.plannedCities,
          plannedStartDate: result.plannedStartDate,
          plannedEndDate: result.plannedEndDate,
        ),
      );
      if (result.openPlannerAfterSave && mounted) {
        context.push('/wishlist/plan/$insertedId');
      }
      return;
    }

    await repository.updateWishlistItem(
      existing.copyWith(
        title: result.title,
        countryName: result.countryName,
        countryCode: result.countryCode,
        plannedCities: result.plannedCities,
        plannedStartDate: result.plannedStartDate,
        plannedEndDate: result.plannedEndDate,
      ),
    );
    if (result.openPlannerAfterSave && existing.id != null && mounted) {
      context.push('/wishlist/plan/${existing.id}');
    }
  }
}

extension _WishlistScreenDialogMethods on _WishlistScreenState {
  Future<void> _deleteItem({
    required WishlistItemRecord item,
    required bool requireConfirmation,
  }) async {
    final id = item.id;
    if (id == null) {
      return;
    }

    if (requireConfirmation) {
      final shouldDelete = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Delete wishlist item?'),
                content: Text('Remove "${item.title}" from wishlist?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              );
            },
          ) ??
          false;
      if (!shouldDelete) {
        return;
      }
    }

    await ref.read(wishlistRepositoryProvider).deleteWishlistItem(id);
  }

  String? _optional(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
