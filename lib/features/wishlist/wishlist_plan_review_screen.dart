import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/frosted_squircle.dart';
import 'gemini_trip_planner.dart';
import 'widgets/wishlist_editorial_widgets.dart';

const _topClearance = 114.0;
const _bottomClearance = 36.0;
const _emptyDockClearance = 188.0;

class WishlistPlanReviewScreen extends ConsumerWidget {
  const WishlistPlanReviewScreen({
    super.key,
    required this.itemId,
  });

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(wishlistItemProvider(itemId));
    final planner = ref.read(geminiTripPlannerProvider);

    return itemAsync.when(
      loading: () => const _ReviewShell(
        body: WishlistScrollView(
          bottomPadding: _bottomClearance,
          children: <Widget>[
            SizedBox(height: _topClearance),
            WishlistHorizontalPadding(
              child: WishlistStatusCard(
                title: 'Loading itinerary',
                message: 'Pulling together this wishlist plan.',
                showProgress: true,
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => _ReviewShell(
        body: WishlistScrollView(
          bottomPadding: _bottomClearance,
          children: <Widget>[
            const SizedBox(height: _topClearance),
            WishlistHorizontalPadding(
              child: WishlistStatusCard(
                title: 'Plan unavailable',
                message: 'Failed to load this wishlist item: $error',
              ),
            ),
          ],
        ),
      ),
      data: (item) {
        if (item == null) {
          return const _ReviewShell(
            body: WishlistScrollView(
              bottomPadding: _bottomClearance,
              children: <Widget>[
                SizedBox(height: _topClearance),
                WishlistHorizontalPadding(
                  child: WishlistStatusCard(
                    title: 'Wishlist item not found',
                    message: 'This destination is no longer available.',
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

        return _ReviewShell(
          onStartTrip: item.id == null
              ? null
              : () => context.push('/trips/add?wishlistId=${item.id}'),
          onEdit: () => _openEditActions(context, item.id),
          bottomDock: plan == null ? _EmptyPlanDock(itemId: item.id) : null,
          body: WishlistScrollView(
            bottomPadding: plan == null
                ? _bottomClearance + _emptyDockClearance
                : _bottomClearance,
            children: <Widget>[
              const SizedBox(height: _topClearance),
              WishlistHorizontalPadding(
                child: _HeroCard(item: item, plan: plan),
              ),
              const SizedBox(height: 18),
              WishlistHorizontalPadding(
                child: _ReadinessCard(item: item),
              ),
              if (plan != null) ...<Widget>[
                const SizedBox(height: 18),
                WishlistHorizontalPadding(
                  child: _PlanOverviewCard(plan: plan),
                ),
                if (plan.timeWindows.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  WishlistHorizontalPadding(
                    child: _GlassSection(
                      title: 'Season Notes',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (var i = 0;
                              i < plan.timeWindows.length;
                              i += 1) ...<Widget>[
                            _TimeWindowCard(window: plan.timeWindows[i]),
                            if (i != plan.timeWindows.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                WishlistHorizontalPadding(
                  child: _CitySection(
                    itemId: item.id,
                    plan: plan,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditActions(BuildContext context, int? id) async {
    if (id == null) {
      return;
    }

    final action = await showModalBottomSheet<_PlanEditAction>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FrostedSquircle(
              radius: 30,
              blurSigma: 18,
              color: scheme.surface.withValues(alpha: 0.74),
              borderColor: scheme.primaryContainer.withValues(alpha: 0.14),
              shadowColor: scheme.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: scheme.outlineVariant.withValues(alpha: 0.55),
                        shape: squircleShape(8),
                      ),
                      child: const SizedBox(width: 36, height: 4),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('Regenerate with AI'),
                      subtitle: const Text(
                          'Refresh the draft and keep your manual edits.'),
                      onTap: () => Navigator.of(sheetContext)
                          .pop(_PlanEditAction.aiEdit),
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_note_outlined),
                      title: const Text('Edit manually'),
                      subtitle: const Text(
                          'Adjust cities, timing, and notes yourself.'),
                      onTap: () => Navigator.of(sheetContext)
                          .pop(_PlanEditAction.manualEdit),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case _PlanEditAction.aiEdit:
        context.push('/wishlist/plan/$id/ai-edit');
      case _PlanEditAction.manualEdit:
        context.push('/wishlist/plan/$id/manual-edit');
    }
  }
}

class _ReviewShell extends StatelessWidget {
  const _ReviewShell({
    required this.body,
    this.onStartTrip,
    this.onEdit,
    this.bottomDock,
  });

  final Widget body;
  final VoidCallback? onStartTrip;
  final VoidCallback? onEdit;
  final Widget? bottomDock;

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
                  child: _TopBar(
                    onBack: () => Navigator.of(context).maybePop(),
                    onStartTrip: onStartTrip,
                    onEdit: onEdit,
                  ),
                ),
              ),
            ),
            if (bottomDock != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: SafeArea(
                  top: false,
                  child: bottomDock!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    this.onStartTrip,
    this.onEdit,
  });

  final VoidCallback onBack;
  final VoidCallback? onStartTrip;
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
                child: _TopBarButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Plan Review',
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _TopBarButton(
                      icon: Icons.flight_takeoff_rounded,
                      onTap: onStartTrip,
                    ),
                    const SizedBox(width: 2),
                    _TopBarButton(
                      icon: Icons.edit_outlined,
                      onTap: onEdit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.item,
    required this.plan,
  });

  final WishlistItemRecord item;
  final GeminiTripPlan? plan;

  @override
  Widget build(BuildContext context) {
    final imageUrl = wishlistPrimaryImageUrl(item);
    final destination = _destination(item, plan);
    final chips = <String>[
      if (plan?.stayDuration != null) '${plan!.stayDuration!.days} days',
      if (plan != null && plan!.cityPlan.isNotEmpty)
        '${plan!.cityPlan.length} cities',
    ];

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
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const _HeroFallback(),
                )
              else
                const _HeroFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.68),
                    ],
                    stops: const <double>[0, 0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                child: _HeroPill(
                    label: plan == null ? 'Wishlist idea' : 'Saved itinerary'),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
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
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (chips.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: chips
                            .map((label) => _HeroPill(label: label))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _destination(WishlistItemRecord item, GeminiTripPlan? plan) {
    final fromPlan = plan?.country.trim() ?? '';
    if (fromPlan.isNotEmpty) {
      return fromPlan;
    }
    final fromItem = item.countryName?.trim() ?? '';
    if (fromItem.isNotEmpty) {
      return fromItem;
    }
    return 'Destination still being shaped';
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

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
            center: const Alignment(0.6, -0.2),
            radius: 1.25,
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.item});

  final WishlistItemRecord item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snapshot = wishlistReadinessSnapshot(item);
    final remaining = snapshot.remainingSteps;

    return _GlassSection(
      title: '${snapshot.score}% ready',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Readiness rises as you name the idea, confirm the destination, save an itinerary draft, and lock exact travel dates.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: snapshot.score / 100,
              minHeight: 8,
              backgroundColor:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 16),
          if (remaining.isEmpty)
            Text(
              'Everything needed for a solid draft is already in place.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'To reach 100%:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < remaining.length; i += 1) ...<Widget>[
                  _ReadinessStepTile(step: remaining[i]),
                  if (i != remaining.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ReadinessStepTile extends StatelessWidget {
  const _ReadinessStepTile({required this.step});

  final WishlistReadinessStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.82),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.42),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.add_task_rounded,
                  size: 16,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                step.label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '+${step.points}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.secondary,
                    letterSpacing: 0.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fillColor = highlighted
        ? scheme.primaryContainer.withValues(alpha: 0.76)
        : scheme.surface.withValues(alpha: 0.72);

    return FrostedSquircle(
      radius: 28,
      blurSigma: 18,
      color: fillColor,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 22,
                  color: highlighted
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: highlighted
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
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

class _GlassSection extends StatelessWidget {
  const _GlassSection({
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptyPlanDock extends StatelessWidget {
  const _EmptyPlanDock({required this.itemId});

  final int? itemId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DockButton(
          label: 'Generate with AI',
          icon: Icons.auto_awesome_outlined,
          highlighted: true,
          onTap: itemId == null
              ? null
              : () => context.push('/wishlist/plan/$itemId/ai-edit'),
        ),
        const SizedBox(height: 12),
        _DockButton(
          label: 'Create manually',
          icon: Icons.edit_note_outlined,
          onTap: itemId == null
              ? null
              : () => context.push('/wishlist/plan/$itemId/manual-edit'),
        ),
      ],
    );
  }
}

class _PlanOverviewCard extends StatelessWidget {
  const _PlanOverviewCard({required this.plan});

  final GeminiTripPlan plan;

  @override
  Widget build(BuildContext context) {
    final summary = plan.summary.trim().isEmpty
        ? 'A saved draft is ready for this destination.'
        : plan.summary.trim();
    final durationReason = plan.stayDuration?.reason.trim() ?? '';

    return _GlassSection(
      title: 'Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(summary, style: Theme.of(context).textTheme.bodyLarge),
          if (durationReason.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerLowest
                    .withValues(alpha: 0.82),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Why this length works',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      durationReason,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeWindowCard extends StatelessWidget {
  const _TimeWindowCard({required this.window});

  final GeminiTimeWindow window;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthPills = _seasonMonthPills(window.months);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.84),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              window.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (monthPills.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: monthPills
                    .map(
                      (label) => _MetaChip(
                        label: label,
                        emphasized: true,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              window.reason,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitySection extends StatelessWidget {
  const _CitySection({
    required this.itemId,
    required this.plan,
  });

  final int? itemId;
  final GeminiTripPlan plan;

  @override
  Widget build(BuildContext context) {
    final detailByCity = <String, GeminiCityDetail>{
      for (final detail in plan.cityDetails) _cityKey(detail.city): detail,
    };

    return _GlassSection(
      title: 'Route details',
      child: plan.cityPlan.isEmpty
          ? Text(
              'No city details are saved yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: <Widget>[
                for (var i = 0; i < plan.cityPlan.length; i += 1) ...<Widget>[
                  _CityCard(
                    itemId: itemId,
                    cityIndex: i,
                    city: plan.cityPlan[i],
                    detail: detailByCity[_cityKey(plan.cityPlan[i].city)],
                  ),
                  if (i != plan.cityPlan.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.itemId,
    required this.cityIndex,
    required this.city,
    required this.detail,
  });

  final int? itemId;
  final int cityIndex;
  final GeminiCityPlan city;
  final GeminiCityDetail? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final city = this.city;
    final detail = this.detail;
    final timeline = detail?.timeline ?? const <GeminiTimelineStop>[];
    final things = detail?.thingsToDo ?? const <String>[];
    final imageUrl = detail?.image?.imageUrl.trim();
    final overview = (detail?.overview ?? city.reason).trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Material(
          color: scheme.surfaceContainerLowest.withValues(alpha: 0.88),
          child: InkWell(
            onTap: itemId == null
                ? null
                : () => context.push('/wishlist/plan/$itemId/city/$cityIndex'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 228,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const _CityImageFallback(),
                        )
                      else
                        const _CityImageFallback(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.08),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.72),
                            ],
                            stops: const <double>[0, 0.38, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MetaChip(
                              label: '${city.days} days',
                              icon: Icons.schedule_rounded,
                              emphasized: true,
                            ),
                            if (city.isExtra)
                              _MetaChip(
                                label: 'Extra city',
                                icon: Icons.add_location_alt_outlined,
                                emphasized: true,
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    city.city,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 34,
                                          height: 0.96,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    city.reason,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.86),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.arrow_outward_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (overview.isNotEmpty) ...<Widget>[
                        Text(
                          overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (timeline.isNotEmpty)
                            _MetaChip(
                              label: '${timeline.length} stops',
                              icon: Icons.route_outlined,
                            ),
                          if (things.isNotEmpty)
                            _MetaChip(
                              label: '${things.length} ideas',
                              icon: Icons.checklist_rounded,
                            ),
                          const _MetaChip(
                            label: 'Open city guide',
                            icon: Icons.open_in_new_rounded,
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
      ),
    );
  }
}

class _CityImageFallback extends StatelessWidget {
  const _CityImageFallback();

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
            scheme.surfaceContainerLow.withValues(alpha: 0.96),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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
            ? scheme.primaryContainer.withValues(alpha: 0.36)
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
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PlanEditAction {
  aiEdit,
  manualEdit,
}

List<String> _seasonMonthPills(String raw) {
  final normalized = raw.trim().replaceAll('–', '-');
  if (normalized.isEmpty) {
    return const <String>[];
  }
  if (normalized.contains('-')) {
    return <String>[normalized];
  }
  final parts = normalized
      .split(RegExp(r'\s+and\s+|,'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return parts.isEmpty ? <String>[normalized] : parts;
}

String _cityKey(String value) => value.trim().toLowerCase();
