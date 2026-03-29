import 'package:flutter/material.dart';

import '../../../features/map/globe/globe_country_data.dart';
import '../../../features/map/globe/globe_painter.dart';
import '../../../features/map/globe/globe_projection.dart';

class ReadOnlyGlobeCard extends StatefulWidget {
  const ReadOnlyGlobeCard({
    super.key,
    required this.visitedCountryCodes,
    required this.title,
    required this.subtitle,
  });

  final List<String> visitedCountryCodes;
  final String title;
  final String subtitle;

  @override
  State<ReadOnlyGlobeCard> createState() => _ReadOnlyGlobeCardState();
}

class _ReadOnlyGlobeCardState extends State<ReadOnlyGlobeCard> {
  static final Future<GlobeCountryDataset> _datasetFuture =
      GlobeCountryDatasetLoader.load();

  double _rotation = 0.36;
  double _pitch = -0.22;
  static const double _fixedZoom = 1.08;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visitedSet =
        widget.visitedCountryCodes.map((code) => code.toUpperCase()).toSet();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: FutureBuilder<GlobeCountryDataset>(
          future: _datasetFuture,
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 220,
                    child: snapshot.hasData
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (details) {
                              setState(() {
                                _rotation = GlobeProjection.normalizeAngle(
                                  _rotation +
                                      (details.delta.dx * 0.0095 / _fixedZoom),
                                );
                                _pitch = (_pitch +
                                        (details.delta.dy * 0.0062 / _fixedZoom))
                                    .clamp(-1.2, 1.2);
                              });
                            },
                            child: CustomPaint(
                              painter: GlobePainter(
                                colorScheme: colorScheme,
                                rotation: _rotation,
                                pitch: _pitch,
                                zoom: _fixedZoom,
                                lodLevel: 0,
                                countries: snapshot.data!.countries,
                                visitedCountryCodes: visitedSet,
                                selectedCountryCode: null,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          )
                        : Center(
                            child: snapshot.hasError
                                ? Icon(
                                    Icons.public_off,
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : const CircularProgressIndicator(),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
