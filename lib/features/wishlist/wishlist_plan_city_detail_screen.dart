import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/frosted_squircle.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_ui_state.dart';
import 'widgets/wishlist_editorial_widgets.dart';

const _cityTopClearance = 114.0;
const _cityBottomClearance = 40.0;

class WishlistPlanCityDetailScreen extends ConsumerStatefulWidget {
  const WishlistPlanCityDetailScreen({
    super.key,
    required this.itemId,
    required this.cityIndex,
  });

  final int itemId;
  final int cityIndex;

  @override
  ConsumerState<WishlistPlanCityDetailScreen> createState() =>
      _WishlistPlanCityDetailScreenState();
}

class _WishlistPlanCityDetailScreenState
    extends ConsumerState<WishlistPlanCityDetailScreen> {
  Set<String>? _completedThingKeys;
  String? _completionSeed;

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(wishlistItemProvider(widget.itemId));
    final planner = ref.read(geminiTripPlannerProvider);

    return itemAsync.when(
      loading: () => const _WishlistCityShell(
        title: 'City',
        body: WishlistScrollView(
          bottomPadding: _cityBottomClearance,
          children: <Widget>[
            SizedBox(height: _cityTopClearance),
            WishlistHorizontalPadding(
              child: WishlistStatusCard(
                title: 'Loading city guide',
                message: 'Pulling together the route details for this stop.',
                showProgress: true,
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => _WishlistCityShell(
        title: 'City',
        body: WishlistScrollView(
          bottomPadding: _cityBottomClearance,
          children: <Widget>[
            const SizedBox(height: _cityTopClearance),
            WishlistHorizontalPadding(
              child: WishlistStatusCard(
                title: 'City unavailable',
                message: 'Failed to load this city: $error',
              ),
            ),
          ],
        ),
      ),
      data: (item) {
        if (item == null) {
          return const _WishlistCityShell(
            title: 'City',
            body: WishlistScrollView(
              bottomPadding: _cityBottomClearance,
              children: <Widget>[
                SizedBox(height: _cityTopClearance),
                WishlistHorizontalPadding(
                  child: WishlistStatusCard(
                    title: 'City unavailable',
                    message: 'This wishlist item is no longer available.',
                  ),
                ),
              ],
            ),
          );
        }

        final plan = planner.parseStoredPlan(
          item.aiPlan ?? '',
          fallbackCountry: item.countryName ?? '',
        );
        if (plan == null || plan.cityPlan.isEmpty) {
          return _WishlistCityShell(
            title: item.title,
            onEdit: () => _openManualEdit(context),
            body: const WishlistScrollView(
              bottomPadding: _cityBottomClearance,
              children: <Widget>[
                SizedBox(height: _cityTopClearance),
                WishlistHorizontalPadding(
                  child: WishlistStatusCard(
                    title: 'No route saved yet',
                    message:
                        'Generate or create an itinerary before opening a city guide.',
                  ),
                ),
              ],
            ),
          );
        }
        if (widget.cityIndex < 0 || widget.cityIndex >= plan.cityPlan.length) {
          return _WishlistCityShell(
            title: item.title,
            onEdit: () => _openManualEdit(context),
            body: const WishlistScrollView(
              bottomPadding: _cityBottomClearance,
              children: <Widget>[
                SizedBox(height: _cityTopClearance),
                WishlistHorizontalPadding(
                  child: WishlistStatusCard(
                    title: 'City not found',
                    message: 'That stop is no longer part of this itinerary.',
                  ),
                ),
              ],
            ),
          );
        }

        final city = plan.cityPlan[widget.cityIndex];
        final detail = _cityDetailFor(plan: plan, cityName: city.city);
        final overview = (detail?.overview ?? city.reason).trim();
        final timeline = detail?.timeline ?? const <GeminiTimelineStop>[];
        final things = detail?.thingsToDo ?? const <String>[];
        final completedThingKeys = _syncCompletedThings(
          item: item,
          cityName: city.city,
          things: things,
        );

        return _WishlistCityShell(
          title: city.city,
          onEdit: () => _openManualEdit(context),
          body: WishlistScrollView(
            bottomPadding: _cityBottomClearance,
            children: <Widget>[
              const SizedBox(height: _cityTopClearance),
              WishlistHorizontalPadding(
                child: _WishlistCityHero(
                  city: city,
                  countryName: plan.country.trim().isNotEmpty
                      ? plan.country
                      : (item.countryName ?? 'Destination'),
                  detail: detail,
                ),
              ),
              const SizedBox(height: 24),
              WishlistHorizontalPadding(
                child: _WishlistCitySection(
                  title: 'City focus',
                  subtitle:
                      'The essence of why this stop belongs in the route.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _WishlistCityMetaRow(
                        children: <Widget>[
                          _WishlistCityMetaChip(
                            label: '${city.days} days planned',
                            emphasized: true,
                          ),
                          if (city.isExtra)
                            const _WishlistCityMetaChip(
                              label: 'Extra city',
                              icon: Icons.add_location_alt_outlined,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        city.reason,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (overview.isNotEmpty &&
                          overview.toLowerCase() !=
                              city.reason.toLowerCase()) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          overview,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              WishlistHorizontalPadding(
                child: _WishlistCitySection(
                  title: 'Day flow',
                  subtitle:
                      'A clearer beat-by-beat rhythm for how this city can unfold.',
                  child: timeline.isEmpty
                      ? Text(
                          'No timeline stops are saved for this city yet.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        )
                      : Column(
                          children: <Widget>[
                            for (var i = 0;
                                i < timeline.length;
                                i += 1) ...<Widget>[
                              _WishlistTimelineCard(stop: timeline[i]),
                              if (i != timeline.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              WishlistHorizontalPadding(
                child: _WishlistCitySection(
                  title: 'Things to do',
                  subtitle:
                      'Check these off as you shape the city into a real trip.',
                  child: things.isEmpty
                      ? Text(
                          'No city activities are saved yet.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${completedThingKeys.length}/${things.length} checked',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0;
                                i < things.length;
                                i += 1) ...<Widget>[
                              _WishlistThingTile(
                                label: things[i],
                                checked: completedThingKeys.contains(
                                  normalizeWishlistPlanThingKey(things[i]),
                                ),
                                onTap: () => _toggleThingCompletion(
                                  item: item,
                                  cityName: city.city,
                                  label: things[i],
                                ),
                              ),
                              if (i != things.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openManualEdit(BuildContext context) async {
    await context.push('/wishlist/plan/${widget.itemId}/manual-edit');
    ref.invalidate(wishlistItemProvider(widget.itemId));
    ref.invalidate(wishlistStreamProvider);
  }

  GeminiCityDetail? _cityDetailFor({
    required GeminiTripPlan plan,
    required String cityName,
  }) {
    final key = normalizeWishlistPlanCityKey(cityName);
    for (final detail in plan.cityDetails) {
      if (normalizeWishlistPlanCityKey(detail.city) == key) {
        return detail;
      }
    }
    return null;
  }

  Set<String> _syncCompletedThings({
    required WishlistItemRecord item,
    required String cityName,
    required List<String> things,
  }) {
    final seed = '${item.aiPlan}|${normalizeWishlistPlanCityKey(cityName)}';
    if (_completionSeed != seed || _completedThingKeys == null) {
      _completionSeed = seed;
      _completedThingKeys = readWishlistCompletedThingKeys(
        rawPlan: item.aiPlan,
        cityName: cityName,
      );
    }

    final availableThingKeys =
        things.map(normalizeWishlistPlanThingKey).toSet();
    final filtered = (_completedThingKeys ?? const <String>{})
        .where(availableThingKeys.contains)
        .toSet();
    _completedThingKeys = filtered;
    return filtered;
  }

  Future<void> _toggleThingCompletion({
    required WishlistItemRecord item,
    required String cityName,
    required String label,
  }) async {
    final thingKey = normalizeWishlistPlanThingKey(label);
    final previous = Set<String>.from(_completedThingKeys ?? const <String>{});
    final nextCompleted = !previous.contains(thingKey);

    setState(() {
      final next = Set<String>.from(previous);
      if (nextCompleted) {
        next.add(thingKey);
      } else {
        next.remove(thingKey);
      }
      _completedThingKeys = next;
    });

    final updatedRawPlan = writeWishlistThingCompletionState(
      rawPlan: item.aiPlan,
      cityName: cityName,
      thingLabel: label,
      completed: nextCompleted,
    );
    if (updatedRawPlan == null || updatedRawPlan == item.aiPlan) {
      return;
    }

    try {
      await ref.read(wishlistRepositoryProvider).updateWishlistItem(
            item.copyWith(aiPlan: updatedRawPlan),
          );
      ref.invalidate(wishlistItemProvider(widget.itemId));
      ref.invalidate(wishlistStreamProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _completedThingKeys = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update checklist: $error')),
      );
    }
  }
}

class _WishlistCityShell extends StatelessWidget {
  const _WishlistCityShell({
    required this.title,
    required this.body,
    this.onEdit,
  });

  final String title;
  final Widget body;
  final VoidCallback? onEdit;

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
                  child: _WishlistCityTopBar(
                    title: title,
                    onBack: () => Navigator.of(context).maybePop(),
                    onEdit: onEdit,
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

class _WishlistCityTopBar extends StatelessWidget {
  const _WishlistCityTopBar({
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
        height: 34,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _WishlistTopBarButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
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
                    ),
              ),
            ),
            SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerRight,
                child: _WishlistTopBarButton(
                  icon: Icons.edit_outlined,
                  onTap: onEdit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistTopBarButton extends StatelessWidget {
  const _WishlistTopBarButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 20,
        color: onTap == null
            ? scheme.onSurface.withValues(alpha: 0.34)
            : scheme.onSurface,
      ),
    );
  }
}

class _WishlistCityHero extends StatelessWidget {
  const _WishlistCityHero({
    required this.city,
    required this.countryName,
    required this.detail,
  });

  final GeminiCityPlan city;
  final String countryName;
  final GeminiCityDetail? detail;

  @override
  Widget build(BuildContext context) {
    final imageUrl = detail?.image?.imageUrl.trim();

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
              if (imageUrl != null && imageUrl.isNotEmpty)
                imageUrl.startsWith('http://') || imageUrl.startsWith('https://')
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const _WishlistCityHeroFallback(),
                      )
                    : _LocalWishlistCityImage(imageUrl: imageUrl)
              else
                const _WishlistCityHeroFallback(),
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
                child: _WishlistCityMetaChip(
                  label: city.isExtra ? 'Extra city' : 'City guide',
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
                      city.city,
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
                    _WishlistCityMetaRow(
                      children: <Widget>[
                        _WishlistCityMetaChip(
                          label: '${city.days} days',
                          icon: Icons.schedule_rounded,
                        ),
                        if ((detail?.timeline.length ?? 0) > 0)
                          _WishlistCityMetaChip(
                            label: '${detail!.timeline.length} stops',
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

class _LocalWishlistCityImage extends StatelessWidget {
  const _LocalWishlistCityImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final localPath = imageUrl.startsWith('file://')
        ? imageUrl.replaceFirst('file://', '')
        : imageUrl;
    final file = File(localPath);
    if (!file.existsSync()) {
      return const _WishlistCityHeroFallback();
    }
    return Image.file(file, fit: BoxFit.cover);
  }
}

class _WishlistCityHeroFallback extends StatelessWidget {
  const _WishlistCityHeroFallback();

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

class _WishlistCitySection extends StatelessWidget {
  const _WishlistCitySection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _WishlistTimelineCard extends StatelessWidget {
  const _WishlistTimelineCard({required this.stop});

  final GeminiTimelineStop stop;

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
            _WishlistCityMetaRow(
              children: <Widget>[
                _WishlistCityMetaChip(
                  label: slot.dayLabel,
                  emphasized: true,
                ),
                _WishlistCityMetaChip(
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stop.note,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
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

class _WishlistThingTile extends StatelessWidget {
  const _WishlistThingTile({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

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

class _WishlistCityMetaRow extends StatelessWidget {
  const _WishlistCityMetaRow({required this.children});

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

class _WishlistCityMetaChip extends StatelessWidget {
  const _WishlistCityMetaChip({
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

class _WishlistTimelineSlot {
  const _WishlistTimelineSlot({
    required this.dayLabel,
    required this.phaseLabel,
  });

  final String dayLabel;
  final String phaseLabel;
}

_WishlistTimelineSlot _parseTimelineSlot(String rawSlot) {
  final normalized = rawSlot.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return const _WishlistTimelineSlot(
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
    return _WishlistTimelineSlot(
      dayLabel: dayLabel,
      phaseLabel: phaseLabel.trim().isEmpty ? 'Scheduled' : phaseLabel,
    );
  }

  return _WishlistTimelineSlot(
    dayLabel: 'Route stop',
    phaseLabel: _capitalizeWords(normalized),
  );
}

String _capitalizeWords(String raw) {
  return raw
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
