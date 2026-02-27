import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/wishlist_repository.dart';
import 'gemini_trip_planner.dart';

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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Plan Review')),
        body: Center(child: Text('Failed to load item: $error')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Plan Review')),
            body: const Center(child: Text('Wishlist item not found.')),
          );
        }

        final parsedPlan = planner.parseStoredPlan(
          item.aiPlan ?? '',
          fallbackCountry: item.countryName ?? '',
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Plan Review'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Edit plan',
                onPressed: () => _openEditActions(context, item.id),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 23,
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.route_outlined,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              parsedPlan == null
                                  ? 'No plan yet. Generate with AI or create manually.'
                                  : 'Review your saved itinerary and city-level details.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (parsedPlan == null)
                _EmptyPlanState(itemId: item.id)
              else
                _PlanResultCard(plan: parsedPlan),
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
                title: const Text('AI Regenerate'),
                subtitle:
                    const Text('Update plan with AI (manual fields kept)'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PlanEditAction.aiEdit),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('Manual Edit'),
                subtitle: const Text('Edit all fields in the saved plan'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PlanEditAction.manualEdit),
              ),
            ],
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

class _EmptyPlanState extends StatelessWidget {
  const _EmptyPlanState({required this.itemId});

  final int? itemId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.description_outlined,
              size: 34,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'No saved plan yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Generate one with AI or create a manual draft to start editing.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: itemId == null
                        ? null
                        : () => context.push('/wishlist/plan/$itemId/ai-edit'),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Generate with AI'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: itemId == null
                        ? null
                        : () =>
                            context.push('/wishlist/plan/$itemId/manual-edit'),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Create manually'),
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

class _PlanResultCard extends StatelessWidget {
  const _PlanResultCard({required this.plan});

  final GeminiTripPlan plan;

  @override
  Widget build(BuildContext context) {
    final detailByCity = <String, GeminiCityDetail>{
      for (final detail in plan.cityDetails) _cityKey(detail.city): detail,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Saved Plan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(plan.summary),
            if (plan.stayDuration != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 14,
                      child: Text('${plan.stayDuration!.days}d'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            plan.stayDuration!.source == 'user_selected'
                                ? 'Duration matched to your preference'
                                : 'AI-recommended trip duration',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.stayDuration!.reason,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (plan.timeWindows.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Best Time Windows',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              ...plan.timeWindows.map(
                (window) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          window.label,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(window.months),
                        const SizedBox(height: 4),
                        Text(
                          window.reason,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (plan.cityPlan.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'City Cards',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              ...plan.cityPlan.map(
                (city) => _CityPlanCard(
                  city: city,
                  detail: detailByCity[_cityKey(city.city)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CityPlanCard extends StatelessWidget {
  const _CityPlanCard({
    required this.city,
    required this.detail,
  });

  final GeminiCityPlan city;
  final GeminiCityDetail? detail;

  @override
  Widget build(BuildContext context) {
    final image = detail?.image;
    final timeline = detail?.timeline ?? const <GeminiTimelineStop>[];
    final things = detail?.thingsToDo ?? const <String>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          if (image != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: image.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _CityImagePlaceholder(),
                errorWidget: (_, __, ___) => const _CityImagePlaceholder(),
              ),
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: CircleAvatar(
                radius: 16,
                child: Text('${city.days}d'),
              ),
              title: Row(
                children: <Widget>[
                  Expanded(child: Text(city.city)),
                  if (city.isExtra)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                      child: Text(
                        'Extra city',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(city.reason),
              children: <Widget>[
                if ((detail?.overview ?? '').trim().isNotEmpty) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      detail!.overview,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (timeline.isNotEmpty) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Places timeline',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < timeline.length; i += 1)
                    _TimelineDotItem(
                      stop: timeline[i],
                      isLast: i == timeline.length - 1,
                    ),
                  const SizedBox(height: 8),
                ],
                if (things.isNotEmpty) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Things to do',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in things)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.check_circle_outline, size: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                ],
                if (image != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    child: Text(
                      'Image source: ${image.source} | ${image.license} | ${image.creator}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDotItem extends StatelessWidget {
  const _TimelineDotItem({
    required this.stop,
    required this.isLast,
  });

  final GeminiTimelineStop stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 22,
          child: Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 46,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  stop.slot,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 1),
                Text(
                  stop.place,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  stop.note,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CityImagePlaceholder extends StatelessWidget {
  const _CityImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainer,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: Icon(Icons.photo_camera_back_outlined),
      ),
    );
  }
}

enum _PlanEditAction {
  aiEdit,
  manualEdit,
}

String _cityKey(String value) => value.trim().toLowerCase();
