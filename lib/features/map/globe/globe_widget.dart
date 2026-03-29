import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'globe_country_data.dart';
import 'globe_painter.dart';
import 'globe_projection.dart';

class GlobeWidget extends StatefulWidget {
  const GlobeWidget({
    super.key,
    required this.visitedCountryCodes,
    this.onFocusRequestConsumed,
    this.onInteractionChanged,
    this.onSelectedCountryChanged,
    this.sensitivity = 0.0095,
    this.focusCountryCode,
    this.focusRequestToken,
    this.resetViewRequestToken,
  });

  final List<String> visitedCountryCodes;
  final void Function(String countryCode, int? token)? onFocusRequestConsumed;
  final ValueChanged<bool>? onInteractionChanged;
  final ValueChanged<GlobeCountryShape?>? onSelectedCountryChanged;
  final double sensitivity;
  final String? focusCountryCode;
  final int? focusRequestToken;
  final int? resetViewRequestToken;

  @override
  State<GlobeWidget> createState() => _GlobeWidgetState();
}

class _GlobeWidgetState extends State<GlobeWidget>
    with TickerProviderStateMixin {
  static final Future<GlobeCountryDataset> _datasetFuture =
      GlobeCountryDatasetLoader.load();

  static const _minZoom = 1.0;
  static const _maxZoom = 10.0;
  static const _focusedZoom = 6.2;

  static const _doubleTapIntervalMs = 320;
  static const _doubleTapDistance = 40.0;
  static const _frontVisibilityDepthThreshold = -0.03;
  static const _pitchMin = -1.2;
  static const _pitchMax = 1.2;
  static const _rotationVelocityThreshold = 0.04;
  static const _pitchVelocityThreshold = 0.035;
  static const _zoomVelocityThreshold = 0.07;
  static const _rotationInertiaDecayPerSecond = 3.6;
  static const _zoomInertiaDecayPerSecond = 5.4;
  static const _zoomInertiaVelocityFactor = 0.78;
  static const _maxRotationVelocity = 3.8;
  static const _maxPitchVelocity = 2.6;
  static const _maxZoomVelocity = 6.2;

  late final AnimationController _cameraController;
  Ticker? _inertiaTicker;

  Tween<double>? _rotationTween;
  Tween<double>? _pitchTween;
  Tween<double>? _zoomTween;
  Animation<double>? _cameraCurve;

  double _rotation = 0;
  double _pitch = 0;
  double _zoom = _minZoom;
  int _activeLod = 0;
  int _cameraAnimationGeneration = 0;
  double _scaleStartZoom = _minZoom;

  DateTime? _lastTapAt;
  Offset? _lastTapPosition;
  bool _doubleTapEnabled = true;
  int? _lastHandledFocusToken;
  int? _lastHandledResetToken;
  final Set<int> _activePointers = <int>{};
  bool _isInteracting = false;
  bool _wasMultiTouchGesture = false;
  int? _lastGestureSampleMicros;
  double _rotationVelocity = 0;
  double _pitchVelocity = 0;
  double _zoomVelocity = 0;
  Duration? _lastInertiaElapsed;

  GlobeCountryShape? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )
      ..addListener(_onCameraTick)
      ..addStatusListener(_onCameraStatusChanged);
    _activeLod = _lodForZoom(_zoom);
    _maybeApplyExternalFocus();
  }

  @override
  void didUpdateWidget(covariant GlobeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeApplyResetView(previousToken: oldWidget.resetViewRequestToken);
    _maybeApplyExternalFocus(
      previousCode: oldWidget.focusCountryCode,
      previousToken: oldWidget.focusRequestToken,
    );
  }

  @override
  void dispose() {
    _notifyInteractionChanged(false);
    _stopInertia();
    _inertiaTicker?.dispose();
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

                return Listener(
                  onPointerDown: _handlePointerDown,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  onPointerSignal: _handlePointerSignal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onScaleEnd: _handleScaleEnd,
                    onTapDown: (details) => _handleTapDown(
                      details: details,
                      size: size,
                      dataset: dataset,
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
                              lodLevel: _activeLod,
                              countries: dataset.countries,
                              visitedCountryCodes: visitedSet,
                              selectedCountryCode: _selectedCountry?.iso2,
                            ),
                            child: const SizedBox.expand(),
                          ),
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

    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (resolved is! PointerScrollEvent || !mounted) {
        return;
      }
      _stopCameraAnimation();
      _stopInertia();
      final factor = resolved.scrollDelta.dy > 0 ? 0.9 : 1.1;
      setState(() {
        _setZoom(_zoom * factor);
      });
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _notifyInteractionChanged(true);
    _stopCameraAnimation();
    _stopInertia();
    _scaleStartZoom = _zoom;
    _lastTapAt = null;
    _lastTapPosition = null;
    _wasMultiTouchGesture = false;
    _lastGestureSampleMicros = DateTime.now().microsecondsSinceEpoch;
    _rotationVelocity = 0;
    _pitchVelocity = 0;
    _zoomVelocity = 0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    final dtSeconds = _gestureDeltaSeconds(nowMicros);

    if (details.pointerCount > 1) {
      _wasMultiTouchGesture = true;
      _rotationVelocity = 0;
      _pitchVelocity = 0;
      setState(() {
        final nextZoom = (_scaleStartZoom * details.scale)
            .clamp(_minZoom, _maxZoom)
            .toDouble();
        if (dtSeconds > 0) {
          _zoomVelocity =
              (((nextZoom - _zoom) / dtSeconds) * _zoomInertiaVelocityFactor)
                  .clamp(-_maxZoomVelocity, _maxZoomVelocity)
                  .toDouble();
        }
        _setZoom(nextZoom);
      });
      return;
    }

    if (_wasMultiTouchGesture) {
      _rotationVelocity = 0;
      _pitchVelocity = 0;
      return;
    }

    setState(() {
      final rotationDelta =
          details.focalPointDelta.dx * widget.sensitivity / _zoom;
      final pitchDelta =
          details.focalPointDelta.dy * widget.sensitivity * 0.65 / _zoom;
      _rotation = GlobeProjection.normalizeAngle(_rotation + rotationDelta);
      _pitch = (_pitch + pitchDelta).clamp(_pitchMin, _pitchMax);
      if (dtSeconds > 0) {
        _rotationVelocity = (rotationDelta / dtSeconds)
            .clamp(-_maxRotationVelocity, _maxRotationVelocity)
            .toDouble();
        _pitchVelocity = (pitchDelta / dtSeconds)
            .clamp(-_maxPitchVelocity, _maxPitchVelocity)
            .toDouble();
      }
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastGestureSampleMicros = null;
    if (_wasMultiTouchGesture) {
      _rotationVelocity = 0;
      _pitchVelocity = 0;
    } else {
      final pixelsPerSecond = details.velocity.pixelsPerSecond;
      _rotationVelocity = (pixelsPerSecond.dx * widget.sensitivity / _zoom)
          .clamp(-_maxRotationVelocity, _maxRotationVelocity)
          .toDouble();
      _pitchVelocity =
          ((pixelsPerSecond.dy * widget.sensitivity * 0.65) / _zoom)
              .clamp(-_maxPitchVelocity, _maxPitchVelocity)
              .toDouble();
    }
    _startInertiaIfNeeded();
  }

  void _handleTapDown({
    required TapDownDetails details,
    required Size size,
    required GlobeCountryDataset dataset,
  }) {
    if (!_doubleTapEnabled) {
      return;
    }

    final localPosition = details.localPosition;
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

  void _setSelectedCountry(GlobeCountryShape? country) {
    final previousCode = _selectedCountry?.iso2;
    final nextCode = country?.iso2;
    if (previousCode == nextCode) {
      return;
    }

    setState(() {
      _selectedCountry = country;
    });
    widget.onSelectedCountryChanged?.call(country);
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
    _stopInertia();
    _doubleTapEnabled = false;

    final country = _hitTestCountry(
      localPosition: localPosition,
      size: size,
      dataset: dataset,
    );

    if (country == null) {
      _setSelectedCountry(null);
      _animateCameraTo(
        rotation: _rotation,
        pitch: 0,
        zoom: _minZoom,
        duration: const Duration(milliseconds: 340),
      );
      return;
    }

    final isSameSelection = _selectedCountry?.iso2 == country.iso2;
    if (isSameSelection) {
      _setSelectedCountry(null);
      return;
    }

    _setSelectedCountry(country);

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

        final hitPaths = _buildHitPaths(projected, ring);
        final containsPoint =
            hitPaths.any((path) => path.contains(localPosition));
        if (!containsPoint) {
          continue;
        }

        for (final point in projected) {
          if (!_isFrontFacing(point)) {
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
      polygonHits.sort((left, right) {
        final distanceCmp =
            left.centroidDistance.compareTo(right.centroidDistance);
        if (distanceCmp != 0) {
          return distanceCmp;
        }
        return right.depth.compareTo(left.depth);
      });
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

      final projectedRadius =
          globeRadius * math.sin(country.maxAngularDistanceRad).abs();
      final isTinyCountry =
          country.maxAngularDistanceRad <= 0.22 || projectedRadius <= 18;
      if (!isTinyCountry) {
        continue;
      }

      final distance = (projectedCentroid.offset - localPosition).distance;
      final hitRadius = (projectedRadius * (_zoom >= 3.0 ? 1.35 : 1.65))
          .clamp(10.0, 24.0)
          .toDouble();
      if (distance <= hitRadius) {
        centroidCandidates.add(
          _CountryHitCandidate(
            country: country,
            depth: projectedCentroid.depth,
            centroidDistance: distance / hitRadius,
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

  List<Path> _buildHitPaths(
    List<GlobeProjectedPoint> points,
    List<GlobeGeoPoint> ring,
  ) {
    if (points.length < 4 || ring.length < 4) {
      return const <Path>[];
    }

    final runs = _visibleRuns(points, ring);
    if (runs.isEmpty) {
      return const <Path>[];
    }

    return runs.map((run) {
      final path = Path()..moveTo(run.first.dx, run.first.dy);
      for (final offset in run.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      path.close();
      return path;
    }).toList(growable: false);
  }

  List<List<Offset>> _visibleRuns(
    List<GlobeProjectedPoint> points,
    List<GlobeGeoPoint> ring,
  ) {
    final runs = <List<Offset>>[];
    var current = <Offset>[];

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final previousIndex = index == 0 ? points.length - 1 : index - 1;
      final previousGeo = ring[previousIndex];
      final currentGeo = ring[index];
      final connected = !_isGeoDateLineJump(previousGeo, currentGeo);

      if (_isFrontFacing(point) && (current.isEmpty || connected)) {
        current.add(point.offset);
      } else {
        if (current.length >= 3) {
          runs.add(current);
        }
        current = <Offset>[];
        if (_isFrontFacing(point)) {
          current.add(point.offset);
        }
      }
    }

    if (current.length >= 3) {
      runs.add(current);
    }

    if (runs.isEmpty) {
      return const <List<Offset>>[];
    }

    if (_isFrontFacing(points.first) &&
        _isFrontFacing(points.last) &&
        runs.length >= 2 &&
        !_isGeoDateLineJump(ring.first, ring.last)) {
      final merged = <Offset>[...runs.last, ...runs.first];
      runs
        ..removeAt(runs.length - 1)
        ..removeAt(0)
        ..insert(0, merged);
    }

    return runs.where((run) => run.length >= 3).toList(growable: false);
  }

  bool _isFrontFacing(GlobeProjectedPoint point) {
    return point.depth > _frontVisibilityDepthThreshold;
  }

  bool _isGeoDateLineJump(GlobeGeoPoint left, GlobeGeoPoint right) {
    return (left.lon - right.lon).abs() > 170;
  }

  void _animateCameraTo({
    required double rotation,
    required double pitch,
    required double zoom,
    Duration duration = const Duration(milliseconds: 420),
  }) {
    final generation = ++_cameraAnimationGeneration;
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

    _cameraController.duration = duration;
    _cameraController.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted || generation != _cameraAnimationGeneration) {
        return;
      }
      _doubleTapEnabled = true;
    });
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
      _setZoom(zoomTween.transform(t));
    });
  }

  void _onCameraStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      // `forward(from: 0)` can briefly report `dismissed` before entering
      // `forward` when replaying from a previously completed animation.
      // Treating that as an "animation end" clears tweens too early and
      // breaks subsequent camera transitions.
      return;
    }
    if (status != AnimationStatus.completed) {
      return;
    }

    _rotation = GlobeProjection.normalizeAngle(_rotation);
    _cameraCurve = null;
    _rotationTween = null;
    _pitchTween = null;
    _zoomTween = null;
    _doubleTapEnabled = true;
  }

  double _gestureDeltaSeconds(int nowMicros) {
    final lastMicros = _lastGestureSampleMicros;
    _lastGestureSampleMicros = nowMicros;
    if (lastMicros == null) {
      return 0;
    }

    return ((nowMicros - lastMicros) / Duration.microsecondsPerSecond)
        .clamp(0.0, 0.1);
  }

  void _startInertiaIfNeeded() {
    final shouldRotate =
        _rotationVelocity.abs() >= _rotationVelocityThreshold ||
            _pitchVelocity.abs() >= _pitchVelocityThreshold;
    final shouldZoom = _zoomVelocity.abs() >= _zoomVelocityThreshold;
    if (!shouldRotate && !shouldZoom) {
      _rotationVelocity = 0;
      _pitchVelocity = 0;
      _zoomVelocity = 0;
      return;
    }

    _lastInertiaElapsed = null;
    _inertiaTicker ??= createTicker(_handleInertiaTick);
    _inertiaTicker!.start();
  }

  void _handleInertiaTick(Duration elapsed) {
    final previousElapsed = _lastInertiaElapsed;
    _lastInertiaElapsed = elapsed;
    if (previousElapsed == null) {
      return;
    }

    final dtSeconds = ((elapsed - previousElapsed).inMicroseconds /
            Duration.microsecondsPerSecond)
        .clamp(0.0, 1 / 20);
    if (dtSeconds <= 0) {
      return;
    }

    final rotationDecay = math.exp(-_rotationInertiaDecayPerSecond * dtSeconds);
    final zoomDecay = math.exp(-_zoomInertiaDecayPerSecond * dtSeconds);
    var nextRotationVelocity = _rotationVelocity * rotationDecay;
    var nextPitchVelocity = _pitchVelocity * rotationDecay;
    var nextZoomVelocity = _zoomVelocity * zoomDecay;

    if (!mounted) {
      _stopInertia();
      return;
    }

    setState(() {
      _rotation = GlobeProjection.normalizeAngle(
        _rotation + (nextRotationVelocity * dtSeconds),
      );

      final unclampedPitch = _pitch + (nextPitchVelocity * dtSeconds);
      final clampedPitch = unclampedPitch.clamp(_pitchMin, _pitchMax);
      if (clampedPitch != unclampedPitch) {
        nextPitchVelocity = 0;
      }
      _pitch = clampedPitch;

      final unclampedZoom = _zoom + (nextZoomVelocity * dtSeconds);
      final clampedZoom = unclampedZoom.clamp(_minZoom, _maxZoom).toDouble();
      if (clampedZoom != unclampedZoom) {
        nextZoomVelocity = 0;
      }
      _setZoom(clampedZoom);
    });

    _rotationVelocity = nextRotationVelocity;
    _pitchVelocity = nextPitchVelocity;
    _zoomVelocity = nextZoomVelocity;

    final done = _rotationVelocity.abs() < _rotationVelocityThreshold &&
        _pitchVelocity.abs() < _pitchVelocityThreshold &&
        _zoomVelocity.abs() < _zoomVelocityThreshold;
    if (done) {
      _stopInertia();
    }
  }

  void _stopCameraAnimation() {
    _cameraAnimationGeneration++;
    if (_cameraController.isAnimating) {
      _cameraController.stop();
    }
    _cameraCurve = null;
    _rotationTween = null;
    _pitchTween = null;
    _zoomTween = null;
    _doubleTapEnabled = true;
  }

  void _stopInertia() {
    if (_inertiaTicker?.isActive ?? false) {
      _inertiaTicker?.stop();
    }
    _lastInertiaElapsed = null;
    _rotationVelocity = 0;
    _pitchVelocity = 0;
    _zoomVelocity = 0;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _notifyInteractionChanged(true);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _notifyInteractionChanged(false);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _notifyInteractionChanged(false);
    }
  }

  void _notifyInteractionChanged(bool interacting) {
    if (_isInteracting == interacting) {
      return;
    }
    _isInteracting = interacting;
    widget.onInteractionChanged?.call(interacting);
  }

  int _lodForZoom(double zoom) {
    if (zoom < 2.8) {
      return 0;
    }
    return 1;
  }

  void _setZoom(double zoom) {
    _zoom = zoom.clamp(_minZoom, _maxZoom);
    _activeLod = _lodForZoom(_zoom);
  }

  void _maybeApplyResetView({
    int? previousToken,
  }) {
    final token = widget.resetViewRequestToken;
    if (token == null ||
        token == previousToken ||
        token == _lastHandledResetToken) {
      return;
    }

    _lastHandledResetToken = token;
    _stopCameraAnimation();
    _stopInertia();
    _lastTapAt = null;
    _lastTapPosition = null;
    _setSelectedCountry(null);
    _animateCameraTo(
      rotation: 0,
      pitch: 0,
      zoom: _minZoom,
      duration: const Duration(milliseconds: 420),
    );
  }

  void _maybeApplyExternalFocus({
    String? previousCode,
    int? previousToken,
  }) {
    final countryCode = widget.focusCountryCode?.trim();
    if (countryCode == null || countryCode.isEmpty) {
      return;
    }

    final token = widget.focusRequestToken;
    if (token != null && token == _lastHandledFocusToken) {
      return;
    }

    final changed = countryCode != previousCode ||
        widget.focusRequestToken != previousToken;
    if (!changed) {
      return;
    }

    _lastHandledFocusToken = token;
    _focusCountryByCode(countryCode, token: token);
  }

  Future<void> _focusCountryByCode(
    String countryCode, {
    int? token,
  }) async {
    final dataset = await _datasetFuture;
    if (!mounted) {
      return;
    }

    final country = dataset.byIso2[countryCode.toUpperCase()];
    if (country == null) {
      return;
    }

    _stopCameraAnimation();
    _stopInertia();
    _setSelectedCountry(country);
    setState(() {
      _lastTapAt = null;
      _lastTapPosition = null;
      _doubleTapEnabled = true;
    });

    final targetRotation = GlobeProjection.nearestAngle(
      current: _rotation,
      target: -country.centroid.lonRad,
    );
    final targetPitch = country.centroid.latRad.clamp(-0.95, 0.95);
    _animateCameraTo(
      rotation: targetRotation,
      pitch: targetPitch,
      zoom: math.max(_zoom, _focusedZoom),
    );
    widget.onFocusRequestConsumed?.call(country.iso2, token);
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
