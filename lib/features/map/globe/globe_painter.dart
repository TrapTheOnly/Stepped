import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'globe_country_data.dart';
import 'globe_projection.dart';

class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.colorScheme,
    required this.rotation,
    required this.pitch,
    required this.zoom,
    required this.lodLevel,
    required this.countries,
    required this.visitedCountryCodes,
    required this.selectedCountryCode,
  });

  final ColorScheme colorScheme;

  final double rotation;

  final double pitch;

  final double zoom;

  final int lodLevel;

  final List<GlobeCountryShape> countries;

  final Set<String> visitedCountryCodes;

  final String? selectedCountryCode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = math.min(size.width, size.height) * 0.42;
    final globeRadius = baseRadius * zoom;
    final projector = GlobeProjection.projector(
      rotation: rotation,
      pitch: pitch,
      center: center,
      radius: globeRadius,
    );

    _paintShadow(canvas, center, baseRadius);
    _paintGlobeBase(canvas, center, globeRadius);

    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: globeRadius)));

    final visibleCountries = _collectVisibleCountries(
      size: size,
      center: center,
      globeRadius: globeRadius,
      projector: projector,
    );

    _paintCountries(
      canvas,
      globeRadius: globeRadius,
      projector: projector,
      countriesToPaint: visibleCountries,
    );

    _paintVisitedMarkers(
      canvas,
      globeRadius: globeRadius,
      countriesToPaint: visibleCountries,
    );

    canvas.restore();

    canvas.drawCircle(
      center,
      globeRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, baseRadius * 0.008)
        ..color = colorScheme.outlineVariant.withValues(alpha: 0.66),
    );
  }

  @override
  bool shouldRepaint(covariant GlobePainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.lodLevel != lodLevel ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.selectedCountryCode != selectedCountryCode ||
        !identical(oldDelegate.countries, countries) ||
        !_sameVisitedCodes(
            oldDelegate.visitedCountryCodes, visitedCountryCodes);
  }
}

class _CountryPaintCandidate {
  const _CountryPaintCandidate({
    required this.country,
    required this.projectedCentroid,
    required this.opacity,
  });

  final GlobeCountryShape country;
  final GlobeProjectedPoint projectedCentroid;
  final double opacity;
}

extension _GlobePainterShapeMethods on GlobePainter {
  bool _sameVisitedCodes(Set<String> left, Set<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final code in left) {
      if (!right.contains(code)) {
        return false;
      }
    }
    return true;
  }

  void _paintShadow(Canvas canvas, Offset center, double baseRadius) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + (baseRadius * 1.08)),
        width: baseRadius * 1.58,
        height: baseRadius * 0.34,
      ),
      Paint()..color = colorScheme.shadow.withValues(alpha: 0.16),
    );
  }

  void _paintGlobeBase(Canvas canvas, Offset center, double globeRadius) {
    final globeRect = Rect.fromCircle(center: center, radius: globeRadius);
    final oceanCenter = _oceanColor(colorScheme.brightness, centerTone: true);
    final oceanEdge = _oceanColor(colorScheme.brightness, centerTone: false);

    final baseShader = RadialGradient(
      center: const Alignment(-0.36, -0.42),
      radius: 1.0,
      colors: <Color>[oceanCenter, oceanEdge],
    ).createShader(globeRect);

    canvas.drawCircle(center, globeRadius, Paint()..shader = baseShader);

    final glowShader = RadialGradient(
      center: const Alignment(-0.5, -0.58),
      radius: 0.7,
      colors: <Color>[
        colorScheme.primary.withValues(alpha: 0.14),
        Colors.transparent,
      ],
    ).createShader(globeRect);

    canvas.drawCircle(center, globeRadius, Paint()..shader = glowShader);
  }

  Color _oceanColor(Brightness brightness, {required bool centerTone}) {
    final base = HSLColor.fromAHSL(
      1,
      205,
      brightness == Brightness.dark ? 0.45 : 0.52,
      brightness == Brightness.dark ? 0.30 : 0.78,
    );
    final shifted = centerTone
        ? base.withLightness((base.lightness + 0.04).clamp(0.0, 1.0))
        : base.withLightness((base.lightness - 0.06).clamp(0.0, 1.0));
    return shifted.toColor();
  }

  List<_CountryPaintCandidate> _collectVisibleCountries({
    required Size size,
    required Offset center,
    required double globeRadius,
    required GlobeProjector projector,
  }) {
    final visible = <_CountryPaintCandidate>[];
    final fadeStart = math.min(size.width, size.height) * 0.35;
    final fadeEnd = math.max(size.width, size.height) * 0.74;

    for (final country in countries) {
      final projected = projector.project(country.centroid);

      if (projected.depth < -0.45) {
        continue;
      }

      final approxRadius =
          (globeRadius * math.sin(country.maxAngularDistanceRad).abs())
              .clamp(6.0, globeRadius);
      if (projected.offset.dx < -approxRadius * 1.6 ||
          projected.offset.dx > size.width + approxRadius * 1.6 ||
          projected.offset.dy < -approxRadius * 1.6 ||
          projected.offset.dy > size.height + approxRadius * 1.6) {
        continue;
      }

      var opacity = 1.0;
      if (zoom > 1.55) {
        final focusDistance = math.max(
            0.0, (projected.offset - center).distance - (approxRadius * 0.8));
        final t = ((focusDistance - fadeStart) / (fadeEnd - fadeStart))
            .clamp(0.0, 1.0);
        opacity = 1 - (t * 0.72);
      }

      if (projected.depth < 0.04) {
        final depthFade = ((projected.depth + 0.16) / 0.2).clamp(0.0, 1.0);
        opacity *= (0.55 + (depthFade * 0.45));
      }

      opacity = opacity.clamp(0.22, 1.0);

      visible.add(
        _CountryPaintCandidate(
          country: country,
          projectedCentroid: projected,
          opacity: opacity,
        ),
      );
    }

    visible.sort((left, right) =>
        left.projectedCentroid.depth.compareTo(right.projectedCentroid.depth));
    return visible;
  }

  void _paintCountries(
    Canvas canvas, {
    required double globeRadius,
    required GlobeProjector projector,
    required List<_CountryPaintCandidate> countriesToPaint,
  }) {
    final landFillColor =
        colorScheme.surfaceContainerHigh.withValues(alpha: 0.9);
    final defaultBorderColor =
        colorScheme.onSurfaceVariant.withValues(alpha: 0.62);
    final visitedFillColor =
        colorScheme.primaryContainer.withValues(alpha: 0.93);
    final visitedBorderColor = colorScheme.primary.withValues(alpha: 0.92);
    final selectedFillColor =
        colorScheme.tertiaryContainer.withValues(alpha: 0.96);
    final selectedBorderColor = colorScheme.tertiary.withValues(alpha: 0.96);

    final baseRadius = globeRadius / zoom.clamp(1.0, 50.0);
    final defaultStroke = (baseRadius * 0.0058).clamp(0.44, 0.92);
    final visitedStroke = (baseRadius * 0.0072).clamp(0.56, 1.18);
    final selectedStroke = (baseRadius * 0.009).clamp(0.74, 1.45);

    for (final candidate in countriesToPaint) {
      final country = candidate.country;
      final isVisited = visitedCountryCodes.contains(country.iso2);
      final isSelected = selectedCountryCode == country.iso2;
      final rings = country.ringsForLod(lodLevel);
      final internalSharedEdges = country.iso2 == 'UA'
          ? _collectInternalSharedEdges(rings)
          : const <String>{};

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = _applyOpacity(
          isSelected
              ? selectedFillColor
              : (isVisited ? visitedFillColor : landFillColor),
          candidate.opacity,
        );

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isSelected
            ? selectedStroke
            : (isVisited ? visitedStroke : defaultStroke)
        ..color = _applyOpacity(
          isSelected
              ? selectedBorderColor
              : (isVisited ? visitedBorderColor : defaultBorderColor),
          candidate.opacity,
        );
      final sealPaint = Paint()
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = borderPaint.strokeWidth * 1.28
        ..color = fillPaint.color;

      for (final ring in rings) {
        final projected = <GlobeProjectedPoint>[
          for (final point in ring) projector.project(point),
        ];

        final fillPaths = _buildVisibleFillPaths(projected, ring);
        for (final fillPath in fillPaths) {
          canvas.drawPath(fillPath, fillPaint);
        }

        final borderPath = _buildVisibleBorderPath(
          projected,
          ring,
          internalSharedEdges,
        );
        if (!borderPath.getBounds().isEmpty) {
          canvas.drawPath(borderPath, sealPaint);
          canvas.drawPath(borderPath, borderPaint);
        }
      }
    }
  }
}

extension _GlobePainterProjectionMethods on GlobePainter {
  void _paintVisitedMarkers(
    Canvas canvas, {
    required double globeRadius,
    required List<_CountryPaintCandidate> countriesToPaint,
  }) {
    for (final candidate in countriesToPaint) {
      final country = candidate.country;
      final isVisited = visitedCountryCodes.contains(country.iso2);
      final isSelected = selectedCountryCode == country.iso2;
      if (!isVisited && !isSelected) {
        continue;
      }

      final projected = candidate.projectedCentroid;
      if (!projected.visible) {
        continue;
      }

      final markerPaint = Paint()
        ..color = _applyOpacity(
          isSelected ? colorScheme.tertiary : colorScheme.primary,
          candidate.opacity,
        );
      final markerInnerPaint = Paint()
        ..color = _applyOpacity(colorScheme.onPrimary, candidate.opacity);

      final baseRadius = globeRadius / zoom.clamp(1.0, 50.0);
      final outerSize = isSelected ? baseRadius * 0.026 : baseRadius * 0.02;
      canvas.drawCircle(
          projected.offset, outerSize.clamp(2.4, 10.0), markerPaint);
      canvas.drawCircle(
        projected.offset,
        (outerSize * 0.42).clamp(1.2, 4.5),
        markerInnerPaint,
      );
    }
  }

  Path _buildVisibleBorderPath(
    List<GlobeProjectedPoint> points,
    List<GlobeGeoPoint> ring,
    Set<String> internalSharedEdges,
  ) {
    final path = Path();
    if (points.length < 2) {
      return path;
    }

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (!_isFront(current) || !_isFront(next)) {
        continue;
      }
      if (_isGeoDateLineJump(ring[i], ring[i + 1])) {
        continue;
      }
      if (internalSharedEdges.isNotEmpty &&
          internalSharedEdges.contains(_segmentKey(ring[i], ring[i + 1]))) {
        continue;
      }

      path.moveTo(current.offset.dx, current.offset.dy);
      path.lineTo(next.offset.dx, next.offset.dy);
    }

    return path;
  }

  List<Path> _buildVisibleFillPaths(
    List<GlobeProjectedPoint> points,
    List<GlobeGeoPoint> ring,
  ) {
    if (points.length < 4) {
      return const <Path>[];
    }

    final runs = _visibleRuns(points, ring);
    if (runs.isEmpty) {
      return const <Path>[];
    }

    final paths = <Path>[];
    for (final run in runs) {
      final path = Path()..moveTo(run.first.dx, run.first.dy);
      for (final offset in run.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      path.close();
      paths.add(path);
    }
    return paths;
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

      if (_isFront(point) && (current.isEmpty || connected)) {
        current.add(point.offset);
      } else {
        if (current.isNotEmpty) {
          runs.add(current);
          current = <Offset>[];
        }
        if (_isFront(point)) {
          current.add(point.offset);
        }
      }
    }

    if (current.isNotEmpty) {
      runs.add(current);
    }

    if (runs.isEmpty) {
      return const <List<Offset>>[];
    }

    if (_isFront(points.first) &&
        _isFront(points.last) &&
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

  bool _isFront(GlobeProjectedPoint point) => point.depth > -0.03;

  bool _isGeoDateLineJump(GlobeGeoPoint left, GlobeGeoPoint right) {
    final lonDelta = (left.lon - right.lon).abs();
    return lonDelta > 170;
  }

  Set<String> _collectInternalSharedEdges(List<List<GlobeGeoPoint>> rings) {
    final counts = <String, int>{};
    for (final ring in rings) {
      if (ring.length < 2) {
        continue;
      }
      for (var i = 0; i < ring.length - 1; i++) {
        final left = ring[i];
        final right = ring[i + 1];
        if (_isGeoDateLineJump(left, right)) {
          continue;
        }
        final key = _segmentKey(left, right);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return {
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key,
    };
  }

  String _segmentKey(GlobeGeoPoint left, GlobeGeoPoint right) {
    final leftKey = _pointKey(left);
    final rightKey = _pointKey(right);
    if (leftKey.compareTo(rightKey) <= 0) {
      return '$leftKey|$rightKey';
    }
    return '$rightKey|$leftKey';
  }

  String _pointKey(GlobeGeoPoint point) {
    final lon = (point.lon * 1000000).round();
    final lat = (point.lat * 1000000).round();
    return '$lon:$lat';
  }

  Color _applyOpacity(Color color, double opacity) {
    return color.withValues(alpha: (color.a * opacity).clamp(0.0, 1.0));
  }
}
