import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../gemini_trip_models.dart';

class WishlistCityPlanCard extends StatelessWidget {
  const WishlistCityPlanCard({
    super.key,
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
                placeholder: (_, __) => const WishlistCityImagePlaceholder(),
                errorWidget: (_, __, ___) =>
                    const WishlistCityImagePlaceholder(),
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
                    WishlistTimelineDotItem(
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

class WishlistTimelineDotItem extends StatelessWidget {
  const WishlistTimelineDotItem({
    super.key,
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

class WishlistCityImagePlaceholder extends StatelessWidget {
  const WishlistCityImagePlaceholder({super.key});

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
