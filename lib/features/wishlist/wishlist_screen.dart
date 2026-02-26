import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/country_flag.dart';
import '../map/map_viewmodel.dart';
import '../map/globe/globe_country_data.dart';
import '../settings/app_preferences.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  final DateFormat _dateFormat = DateFormat.yMMMd();

  @override
  Widget build(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistStreamProvider);
    final preferences = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;
    final dataset = ref.watch(globeCountryDatasetProvider).valueOrNull;
    final countryCodeByName = _countryCodeByName(dataset);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: wishlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load wishlist: $error')),
        data: (items) {
          final aiPlanned =
              items.where((e) => (e.aiPlan ?? '').isNotEmpty).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: <Widget>[
              _WishlistSummary(itemCount: items.length, aiPlanned: aiPlanned),
              const SizedBox(height: 12),
              if (items.isEmpty)
                _EmptyState(
                  onAdd: () =>
                      _showEditor(countryCodeByName: countryCodeByName),
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WishlistCard(
                      item: item,
                      countryCode: _countryCodeFor(item, countryCodeByName),
                      showDate: preferences.showWishlistDates,
                      dateFormat: _dateFormat,
                      onPlan: item.id == null
                          ? null
                          : () => context.push('/wishlist/plan/${item.id}'),
                      onActions: () => _showActions(
                        item: item,
                        countryCodeByName: countryCodeByName,
                        requireDeleteConfirmation:
                            preferences.confirmWishlistDelete,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(countryCodeByName: countryCodeByName),
        icon: const Icon(Icons.add),
        label: const Text('Add idea'),
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

  Future<void> _showActions({
    required WishlistItemRecord item,
    required Map<String, String> countryCodeByName,
    required bool requireDeleteConfirmation,
  }) async {
    final action = await showModalBottomSheet<_WishlistAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Plan with AI'),
                subtitle: const Text('Generate city/day recommendations'),
                enabled: item.id != null,
                onTap: item.id == null
                    ? null
                    : () =>
                        Navigator.of(sheetContext).pop(_WishlistAction.plan),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_WishlistAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_WishlistAction.delete),
              ),
            ],
          ),
        );
      },
    );

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
                  label: const Text('Save + Plan'),
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

class _WishlistSummary extends StatelessWidget {
  const _WishlistSummary({
    required this.itemCount,
    required this.aiPlanned,
  });

  final int itemCount;
  final int aiPlanned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(
                Icons.explore_outlined,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Trip ideas',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    '$itemCount saved · $aiPlanned AI planned',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.item,
    required this.countryCode,
    required this.showDate,
    required this.dateFormat,
    required this.onPlan,
    required this.onActions,
  });

  final WishlistItemRecord item;
  final String? countryCode;
  final bool showDate;
  final DateFormat dateFormat;
  final VoidCallback? onPlan;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAiPlan = (item.aiPlan ?? '').trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (countryCode != null)
                  CountryFlag(iso2: countryCode!, width: 32, height: 22)
                else
                  const CircleAvatar(
                    radius: 14,
                    child: Icon(Icons.bookmark_outline, size: 15),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onActions,
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            if ((item.countryName ?? '').trim().isNotEmpty ||
                hasAiPlan ||
                showDate)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if ((item.countryName ?? '').trim().isNotEmpty)
                      _Badge(
                        icon: Icons.public_outlined,
                        label: item.countryName!.trim(),
                      ),
                    if (item.plannedStartDate != null &&
                        item.plannedEndDate != null)
                      _Badge(
                        icon: Icons.date_range_outlined,
                        label:
                            '${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(item.plannedStartDate!))} - ${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(item.plannedEndDate!))}',
                      ),
                    if ((item.plannedCities ?? '').trim().isNotEmpty)
                      _Badge(
                        icon: Icons.location_city_outlined,
                        label: item.plannedCities!,
                      ),
                    if (hasAiPlan)
                      const _Badge(
                        icon: Icons.auto_awesome_outlined,
                        label: 'AI plan saved',
                      ),
                    if (showDate)
                      _Badge(
                        icon: Icons.schedule_outlined,
                        label:
                            'Saved ${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(item.createdAt))}',
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onPlan,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Plan with AI'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (onPlan == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Save this item first to open AI planner.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: Column(
          children: <Widget>[
            CircleAvatar(
              radius: 30,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(
                Icons.favorite_border,
                color: scheme.onSecondaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No wishlist items yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Add a destination idea, then use AI to plan cities and day allocation.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first idea'),
            ),
          ],
        ),
      ),
    );
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
  edit,
  delete,
}

String _normalizeCountryName(String raw) {
  return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
