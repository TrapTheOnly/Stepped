import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'globe_country_data.dart';
import 'globe_painter.dart';
import 'globe_projection.dart';

class GlobeWidget extends StatefulWidget {
  const GlobeWidget({
    super.key,
    required this.visitedCountryCodes,
    required this.onSetVisited,
    this.sensitivity = 0.0095,
  });

  final List<String> visitedCountryCodes;
  final Future<void> Function(
      String countryCode, String countryName, bool visited) onSetVisited;
  final double sensitivity;

  @override
  State<GlobeWidget> createState() => _GlobeWidgetState();
}

class _GlobeWidgetState extends State<GlobeWidget>
    with SingleTickerProviderStateMixin {
  static final Future<GlobeCountryDataset> _datasetFuture =
      GlobeCountryDatasetLoader.load();

  static const _minZoom = 1.0;
  static const _maxZoom = 10.0;
  static const _focusedZoom = 6.2;
  static const _calloutZoomThreshold = 2.6;

  static const _doubleTapIntervalMs = 320;
  static const _doubleTapDistance = 40.0;

  late final AnimationController _cameraController;

  Tween<double>? _rotationTween;
  Tween<double>? _pitchTween;
  Tween<double>? _zoomTween;
  Animation<double>? _cameraCurve;

  double _rotation = 0;
  double _pitch = 0;
  double _zoom = _minZoom;
  double _scaleStartZoom = _minZoom;

  DateTime? _lastTapAt;
  Offset? _lastTapPosition;
  bool _doubleTapEnabled = true;

  GlobeCountryShape? _selectedCountry;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )
      ..addListener(_onCameraTick)
      ..addStatusListener(_onCameraStatusChanged);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visitedSet =
        widget.visitedCountryCodes.map((code) => code.toUpperCase()).toSet();

    return RepaintBoundary(
      child: Semantics(
        label: 'Interactive globe with country borders',
        child: FutureBuilder<GlobeCountryDataset>(
          future: _datasetFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Icon(Icons.public_off));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final dataset = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final lodLevel = _lodForZoom(_zoom);
                final selectedProjection = _projectSelectedCountry(size);
                final showCallout = _selectedCountry != null &&
                    selectedProjection != null &&
                    _zoom >= _calloutZoomThreshold;

                return Listener(
                  onPointerSignal: _handlePointerSignal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onTapDown: (details) => _handleTapDown(
                      details: details,
                      size: size,
                      dataset: dataset,
                      selectedProjection: selectedProjection,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: GlobePainter(
                              colorScheme: Theme.of(context).colorScheme,
                              rotation: _rotation,
                              pitch: _pitch,
                              zoom: _zoom,
                              lodLevel: lodLevel,
                              countries: dataset.countries,
                              visitedCountryCodes: visitedSet,
                              selectedCountryCode: _selectedCountry?.iso2,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        if (showCallout)
                          _CountryActionCallout(
                            anchor: selectedProjection.offset,
                            size: size,
                            countryName: _selectedCountry!.name,
                            flagEmoji: _flagEmoji(_selectedCountry!.iso2),
                            isVisited:
                                visitedSet.contains(_selectedCountry!.iso2),
                            isBusy: _isSubmitting,
                            onSetVisited: _toggleSelectedCountryVisit,
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    _stopCameraAnimation();
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    setState(() {
      _zoom = (_zoom * factor).clamp(_minZoom, _maxZoom);
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _stopCameraAnimation();
    _scaleStartZoom = _zoom;
    _lastTapAt = null;
    _lastTapPosition = null;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1) {
      setState(() {
        _zoom = (_scaleStartZoom * details.scale).clamp(_minZoom, _maxZoom);
      });
      return;
    }

    setState(() {
      _rotation = GlobeProjection.normalizeAngle(
        _rotation + (details.focalPointDelta.dx * widget.sensitivity / _zoom),
      );
      _pitch = (_pitch -
              (details.focalPointDelta.dy * widget.sensitivity * 0.65 / _zoom))
          .clamp(-1.2, 1.2);
    });
  }

  void _handleTapDown({
    required TapDownDetails details,
    required Size size,
    required GlobeCountryDataset dataset,
    required GlobeProjectedPoint? selectedProjection,
  }) {
    if (_isSubmitting) {
      return;
    }
    if (!_doubleTapEnabled) {
      return;
    }

    final localPosition = details.localPosition;
    if (_isTapInsideCallout(localPosition, size, selectedProjection)) {
      return;
    }

    final now = DateTime.now();
    final lastTapAt = _lastTapAt;
    final lastTapPosition = _lastTapPosition;

    _lastTapAt = now;
    _lastTapPosition = localPosition;

    if (lastTapAt == null || lastTapPosition == null) {
      return;
    }

    final inTime =
        now.difference(lastTapAt).inMilliseconds <= _doubleTapIntervalMs;
    final closeEnough =
        (localPosition - lastTapPosition).distance <= _doubleTapDistance;
    if (!inTime || !closeEnough) {
      return;
    }

    _lastTapAt = null;
    _lastTapPosition = null;

    _handleDoubleTap(
      localPosition: localPosition,
      size: size,
      dataset: dataset,
    );
  }

  void _handleDoubleTap({
    required Offset localPosition,
    required Size size,
    required GlobeCountryDataset dataset,
  }) {
    if (!_doubleTapEnabled) {
      return;
    }
    _stopCameraAnimation();
    _doubleTapEnabled = false;

    final country = _hitTestCountry(
      localPosition: localPosition,
      size: size,
      dataset: dataset,
    );

    if (country == null) {
      setState(() {
        _selectedCountry = null;
      });
      _animateCameraTo(
        rotation: _rotation,
        pitch: 0,
        zoom: _minZoom,
        duration: const Duration(milliseconds: 340),
      );
      return;
    }

    setState(() {
      _selectedCountry = country;
    });

    final targetRotation = GlobeProjection.nearestAngle(
      current: _rotation,
      target: -country.centroid.lonRad,
    );
    final targetPitch = country.centroid.latRad.clamp(-0.95, 0.95);
    _animateCameraTo(
      rotation: targetRotation,
      pitch: targetPitch,
      zoom: _focusedZoom,
    );
  }

  Future<void> _toggleSelectedCountryVisit(bool visited) async {
    final selectedCountry = _selectedCountry;
    if (selectedCountry == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSetVisited(
        selectedCountry.iso2,
        selectedCountry.name,
        visited,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  GlobeProjectedPoint? _projectSelectedCountry(Size size) {
    final country = _selectedCountry;
    if (country == null) {
      return null;
    }

    final center = size.center(Offset.zero);
    final globeRadius = math.min(size.width, size.height) * 0.42 * _zoom;
    final projected = GlobeProjection.project(
      point: country.centroid,
      rotation: _rotation,
      pitch: _pitch,
      center: center,
      radius: globeRadius,
    );

    if (!projected.visible) {
      return null;
    }

    final insideDistance = (projected.offset - center).distance;
    if (insideDistance > globeRadius) {
      return null;
    }

    return projected;
  }

  GlobeCountryShape? _hitTestCountry({
    required Offset localPosition,
    required Size size,
    required GlobeCountryDataset dataset,
  }) {
    final center = size.center(Offset.zero);
    final globeRadius = math.min(size.width, size.height) * 0.42 * _zoom;
    if ((localPosition - center).distance > globeRadius) {
      return null;
    }

    final polygonHits = <_CountryHitCandidate>[];

    for (final country in dataset.countries) {
      final rings = country.ringsForLod(4);
      var bestDepth = -2.0;
      var nearestDistance = double.infinity;

      for (final ring in rings) {
        final projected = <GlobeProjectedPoint>[
          for (final point in ring)
            GlobeProjection.project(
              point: point,
              rotation: _rotation,
              pitch: _pitch,
              center: center,
              radius: globeRadius,
            ),
        ];

        final path = _buildHitPath(projected);
        if (path == null || !path.contains(localPosition)) {
          continue;
        }

        for (final point in projected) {
          if (point.depth <= -0.03) {
            continue;
          }
          bestDepth = math.max(bestDepth, point.depth);
          nearestDistance = math.min(
              nearestDistance, (point.offset - localPosition).distance);
        }
      }

      if (bestDepth > -1.5) {
        polygonHits.add(
          _CountryHitCandidate(
            country: country,
            depth: bestDepth,
            centroidDistance: nearestDistance,
          ),
        );
      }
    }

    if (polygonHits.isNotEmpty) {
      polygonHits.sort((left, right) => right.depth.compareTo(left.depth));
      return polygonHits.first.country;
    }

    // Fallback for tiny countries on touch.
    final centroidCandidates = <_CountryHitCandidate>[];
    for (final country in dataset.countries) {
      final projectedCentroid = GlobeProjection.project(
        point: country.centroid,
        rotation: _rotation,
        pitch: _pitch,
        center: center,
        radius: globeRadius,
      );
      if (!projectedCentroid.visible) {
        continue;
      }

      final distance = (projectedCentroid.offset - localPosition).distance;
      final hitRadius = _zoom >= 3.0 ? 52.0 : 42.0;
      if (distance <= hitRadius) {
        centroidCandidates.add(
          _CountryHitCandidate(
            country: country,
            depth: projectedCentroid.depth,
            centroidDistance: distance / (country.maxAngularDistanceRad + 0.06),
          ),
        );
      }
    }

    if (centroidCandidates.isNotEmpty) {
      centroidCandidates.sort((left, right) {
        final distanceCmp =
            left.centroidDistance.compareTo(right.centroidDistance);
        if (distanceCmp != 0) {
          return distanceCmp;
        }
        return right.depth.compareTo(left.depth);
      });
      return centroidCandidates.first.country;
    }

    return null;
  }

  bool _isTapInsideCallout(
    Offset localPosition,
    Size size,
    GlobeProjectedPoint? selectedProjection,
  ) {
    if (selectedProjection == null ||
        _selectedCountry == null ||
        _zoom < _calloutZoomThreshold) {
      return false;
    }

    final popupWidth = math.min(252.0, size.width - 16);
    final rawLeft = selectedProjection.offset.dx - (popupWidth / 2);
    final left = rawLeft.clamp(8.0, size.width - popupWidth - 8.0).toDouble();
    final topCandidate = selectedProjection.offset.dy - 104;
    final top = topCandidate < 8
        ? (selectedProjection.offset.dy + 20).clamp(8.0, size.height - 80)
        : topCandidate;

    final calloutRect = Rect.fromLTWH(left, top.toDouble(), popupWidth, 56);
    return calloutRect.contains(localPosition);
  }

  Path? _buildHitPath(List<GlobeProjectedPoint> points) {
    if (points.length < 4) {
      return null;
    }

    final visibleOffsets = <Offset>[];
    for (final point in points) {
      if (point.depth > -0.03) {
        visibleOffsets.add(point.offset);
      }
    }

    if (visibleOffsets.length < 3) {
      return null;
    }

    final path = Path()
      ..moveTo(visibleOffsets.first.dx, visibleOffsets.first.dy);
    for (final offset in visibleOffsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    path.close();
    return path;
  }

  void _animateCameraTo({
    required double rotation,
    required double pitch,
    required double zoom,
    Duration duration = const Duration(milliseconds: 420),
  }) {
    final targetRotation = GlobeProjection.nearestAngle(
      current: _rotation,
      target: rotation,
    );

    _rotationTween = Tween<double>(begin: _rotation, end: targetRotation);
    _pitchTween = Tween<double>(begin: _pitch, end: pitch.clamp(-1.1, 1.1));
    _zoomTween =
        Tween<double>(begin: _zoom, end: zoom.clamp(_minZoom, _maxZoom));
    _cameraCurve = CurvedAnimation(
      parent: _cameraController,
      curve: Curves.easeOutCubic,
    );

    _cameraController
      ..duration = duration
      ..forward(from: 0);
  }

  void _onCameraTick() {
    final curve = _cameraCurve;
    final rotationTween = _rotationTween;
    final pitchTween = _pitchTween;
    final zoomTween = _zoomTween;
    if (curve == null ||
        rotationTween == null ||
        pitchTween == null ||
        zoomTween == null) {
      return;
    }

    setState(() {
      final t = curve.value;
      _rotation = rotationTween.transform(t);
      _pitch = pitchTween.transform(t);
      _zoom = zoomTween.transform(t);
    });
  }

  void _onCameraStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }

    _rotation = GlobeProjection.normalizeAngle(_rotation);
    _cameraCurve = null;
    _rotationTween = null;
    _pitchTween = null;
    _zoomTween = null;
    _doubleTapEnabled = true;
  }

  void _stopCameraAnimation() {
    if (_cameraController.isAnimating) {
      _cameraController.stop();
    }
    _cameraCurve = null;
    _rotationTween = null;
    _pitchTween = null;
    _zoomTween = null;
    _doubleTapEnabled = true;
  }

  int _lodForZoom(double zoom) {
    if (zoom < 1.25) {
      return 0;
    }
    if (zoom < 1.9) {
      return 1;
    }
    if (zoom < 2.8) {
      return 2;
    }
    if (zoom < 3.9) {
      return 3;
    }
    return 4;
  }

  String _flagEmoji(String iso2) {
    final normalized = iso2.toUpperCase();
    if (normalized.length != 2) {
      return '🏳';
    }

    final chars = normalized.codeUnits
        .map((char) => 0x1F1E6 + (char - 0x41))
        .toList(growable: false);
    return String.fromCharCodes(chars);
  }
}

class _CountryActionCallout extends StatelessWidget {
  const _CountryActionCallout({
    required this.anchor,
    required this.size,
    required this.countryName,
    required this.flagEmoji,
    required this.isVisited,
    required this.isBusy,
    required this.onSetVisited,
  });

  final Offset anchor;
  final Size size;
  final String countryName;
  final String flagEmoji;
  final bool isVisited;
  final bool isBusy;
  final Future<void> Function(bool visited) onSetVisited;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final popupWidth = math.min(252.0, size.width - 16);
    final rawLeft = anchor.dx - (popupWidth / 2);
    final left = rawLeft.clamp(8.0, size.width - popupWidth - 8.0).toDouble();
    final topCandidate = anchor.dy - 104;
    final top = topCandidate < 8
        ? (anchor.dy + 20).clamp(8.0, size.height - 80)
        : topCandidate;
    final pinTop = (top - 20).clamp(4.0, size.height - 24).toDouble();

    return Stack(
      children: <Widget>[
        Positioned(
          left: (anchor.dx - 10).clamp(4.0, size.width - 24).toDouble(),
          top: pinTop,
          child: Icon(
            Icons.location_pin,
            color: scheme.primary,
            size: 22,
            semanticLabel: 'Selected country pin',
          ),
        ),
        Positioned(
          left: left,
          top: top.toDouble(),
          width: popupWidth,
          child: Material(
            elevation: 4,
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '$flagEmoji  $countryName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Set visited',
                    onPressed:
                        isBusy || isVisited ? null : () => onSetVisited(true),
                    icon: isBusy && !isVisited
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                  ),
                  IconButton(
                    tooltip: 'Unset visited',
                    onPressed:
                        isBusy || !isVisited ? null : () => onSetVisited(false),
                    icon: isBusy && isVisited
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryHitCandidate {
  const _CountryHitCandidate({
    required this.country,
    required this.depth,
    required this.centroidDistance,
  });

  final GlobeCountryShape country;
  final double depth;
  final double centroidDistance;
}
