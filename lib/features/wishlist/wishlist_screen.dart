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

  @override
  Widget build(BuildContext context) {
    return _buildScreenContent(context);
  }
}

enum _WishlistAction {
  plan,
  addToTrips,
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
    required bool requireDeleteConfirmation,
  }) async {
    final action = await showModalBottomSheet<_WishlistAction>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _WishlistActionsSheet(
              item: item,
              onOpenPlan: item.id == null
                  ? null
                  : () => Navigator.of(sheetContext).pop(_WishlistAction.plan),
              onPinToggle: () {
                Navigator.of(sheetContext).pop();
                _togglePinned(item);
              },
              onAddToTrips: () =>
                  Navigator.of(sheetContext).pop(_WishlistAction.addToTrips),
              onDelete: () =>
                  Navigator.of(sheetContext).pop(_WishlistAction.delete),
            ),
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
      case _WishlistAction.addToTrips:
        if (item.id != null) {
          final query = <String, String>{
            'wishlistId': '${item.id}',
            if (item.countryCode != null && item.countryCode!.trim().isNotEmpty)
              'country': item.countryCode!.trim().toUpperCase(),
            if (item.countryName != null && item.countryName!.trim().isNotEmpty)
              'countryName': item.countryName!.trim(),
          };
          context.push(
            Uri(path: '/trips/add', queryParameters: query).toString(),
          );
        }
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
    required this.onAddToTrips,
    required this.onDelete,
    this.onOpenPlan,
  });

  final WishlistItemRecord item;
  final VoidCallback? onOpenPlan;
  final VoidCallback onPinToggle;
  final VoidCallback onAddToTrips;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 34,
      blurSigma: 20,
      color: colorScheme.surface.withValues(alpha: 0.66),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
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
                titleTextStyle:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                subtitleTextStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                titleTextStyle:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                onTap: onPinToggle,
              ),
              ListTile(
                leading: const Icon(Icons.flight_takeoff_rounded),
                title: const Text('Add to Trips'),
                subtitle: const Text('Use this idea to create a real trip'),
                titleTextStyle:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                subtitleTextStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                onTap: onAddToTrips,
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                titleTextStyle:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
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
              final colorScheme = Theme.of(dialogContext).colorScheme;
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: FrostedSquircle(
                  radius: 30,
                  blurSigma: 20,
                  color: colorScheme.surface.withValues(alpha: 0.78),
                  borderColor: colorScheme.outlineVariant.withValues(alpha: 0.16),
                  shadowColor: colorScheme.primary.withValues(alpha: 0.1),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Delete wishlist item?',
                        style: Theme.of(dialogContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Remove "${item.title}" from your wishlist?',
                        style: Theme.of(dialogContext)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _WishlistDialogButton(
                              label: 'Cancel',
                              highlighted: false,
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _WishlistDialogButton(
                              label: 'Delete',
                              highlighted: true,
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
}

class _WishlistDialogButton extends StatelessWidget {
  const _WishlistDialogButton({
    required this.label,
    required this.onTap,
    required this.highlighted,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fillColor = highlighted
        ? scheme.primaryContainer.withValues(alpha: 0.82)
        : scheme.surface.withValues(alpha: 0.72);

    return FrostedSquircle(
      radius: 22,
      blurSigma: 14,
      color: fillColor,
      borderColor: scheme.outlineVariant.withValues(alpha: 0.14),
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: highlighted
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
