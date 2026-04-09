import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'globe_country_data.dart';
import 'globe_projection.dart';

/// CustomPainter that renders the interactive globe.
///
/// The renderer is structured around per-ring drawing:
///
/// * Every disjoint landmass (Alaska, Hawaii, French Guiana, Kalimantan…)
///   is treated as an independent shape, so a country's secondary pieces
///   never disappear because the primary mainland left the field of view.
/// * Polygon clipping happens in 3D camera space against the horizon plane
///   (`z = 0`). When a ring crosses the horizon we follow the silhouette
///   circle with `arcToPoint`, which removes the chord-shaped "ocean" gaps
///   that the previous straight-line closer used to leak onto the disc edge.
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
    final palette = _GlobePalette.fromScheme(colorScheme);

    _paintAmbientShadow(canvas, center, baseRadius, palette);
    _paintAtmosphere(canvas, center, globeRadius, palette);
    _paintSphereSurface(canvas, center, globeRadius, palette);

    canvas.save();
    // Tight oval clip (slightly oversized) ensures any sub-pixel overshoot
    // produced by the silhouette interpolation is hidden behind the rim.
    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: center, radius: globeRadius + 0.5),
        ),
    );

    final renderQueue = _collectRenderItems(
      size: size,
      projector: projector,
      globeRadius: globeRadius,
    );

    final strokeBase = baseRadius;
    final defaultStroke = (strokeBase * 0.0048).clamp(0.42, 0.85);
    final visitedStroke = (strokeBase * 0.0064).clamp(0.55, 1.05);
    final selectedStroke = (strokeBase * 0.0085).clamp(0.72, 1.45);

    for (final item in renderQueue) {
      _paintRing(
        canvas,
        item: item,
        projector: projector,
        center: center,
        radius: globeRadius,
        palette: palette,
        defaultStroke: defaultStroke,
        visitedStroke: visitedStroke,
        selectedStroke: selectedStroke,
      );
    }

    _paintMarkers(
      canvas,
      renderItems: renderQueue,
      projector: projector,
      baseRadius: baseRadius,
      palette: palette,
    );

    canvas.restore();

    _paintRim(canvas, center, globeRadius, palette, baseRadius);
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

  // ---------------------------------------------------------------------------
  // Background & atmosphere
  // ---------------------------------------------------------------------------

  void _paintAmbientShadow(
    Canvas canvas,
    Offset center,
    double baseRadius,
    _GlobePalette palette,
  ) {
    final rect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + (baseRadius * 1.06)),
      width: baseRadius * 1.7,
      height: baseRadius * 0.36,
    );
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        rect.center,
        rect.width * 0.5,
        <Color>[
          palette.ambientShadow.withValues(alpha: 0.42),
          palette.ambientShadow.withValues(alpha: 0.0),
        ],
      );
    canvas.drawOval(rect, paint);
  }

  void _paintAtmosphere(
    Canvas canvas,
    Offset center,
    double globeRadius,
    _GlobePalette palette,
  ) {
    final outerRadius = globeRadius * 1.10;
    final rect = Rect.fromCircle(center: center, radius: outerRadius);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        outerRadius,
        <Color>[
          palette.atmosphere.withValues(alpha: 0.0),
          palette.atmosphere.withValues(alpha: 0.18),
          palette.atmosphere.withValues(alpha: 0.0),
        ],
        <double>[0.86, 0.93, 1.0],
      );
    canvas.drawRect(rect, paint);
  }

  void _paintSphereSurface(
    Canvas canvas,
    Offset center,
    double globeRadius,
    _GlobePalette palette,
  ) {
    // Base ocean fill — soft radial gradient to suggest a 3D sphere without
    // the glossy "globus" feel.
    canvas.drawCircle(
      center,
      globeRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(
            center.dx - (globeRadius * 0.38),
            center.dy - (globeRadius * 0.44),
          ),
          globeRadius * 1.35,
          <Color>[palette.oceanHighlight, palette.oceanBase, palette.oceanDeep],
          <double>[0.0, 0.55, 1.0],
        ),
    );

    // Subtle warm rim light to make the sphere feel lit from above.
    canvas.drawCircle(
      center,
      globeRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(
            center.dx - (globeRadius * 0.55),
            center.dy - (globeRadius * 0.65),
          ),
          globeRadius * 0.8,
          <Color>[
            palette.rimLight.withValues(alpha: 0.18),
            palette.rimLight.withValues(alpha: 0.0),
          ],
        ),
    );

    // Soft inner shadow on the lower-right to deepen the sphere.
    canvas.drawCircle(
      center,
      globeRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(
            center.dx + (globeRadius * 0.45),
            center.dy + (globeRadius * 0.55),
          ),
          globeRadius * 1.1,
          <Color>[
            palette.innerShadow.withValues(alpha: 0.0),
            palette.innerShadow.withValues(alpha: 0.22),
          ],
          <double>[0.6, 1.0],
        ),
    );
  }

  void _paintRim(
    Canvas canvas,
    Offset center,
    double globeRadius,
    _GlobePalette palette,
    double baseRadius,
  ) {
    final rimWidth = math.max(1.0, baseRadius * 0.006);
    canvas.drawCircle(
      center,
      globeRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth
        ..color = palette.rim.withValues(alpha: 0.55),
    );
  }

  // ---------------------------------------------------------------------------
  // Country rendering
  // ---------------------------------------------------------------------------

  List<_RingRenderItem> _collectRenderItems({
    required Size size,
    required GlobeProjector projector,
    required double globeRadius,
  }) {
    final items = <_RingRenderItem>[];
    final viewportMargin = globeRadius * 0.08;
    final viewport = Rect.fromLTRB(
      -viewportMargin,
      -viewportMargin,
      size.width + viewportMargin,
      size.height + viewportMargin,
    );

    for (final country in countries) {
      final isVisited = visitedCountryCodes.contains(country.iso2);
      final isSelected = selectedCountryCode == country.iso2;
      final rings = country.ringsForLod(lodLevel);

      for (final ring in rings) {
        final centroid = projector.project(ring.centroid);
        final maxSin = math.sin(ring.maxAngularDistanceRad).abs();

        // Cull rings that are entirely on the back hemisphere. We allow a
        // tiny epsilon so rings that *just* touch the horizon still draw.
        if (centroid.z + maxSin < -0.02) {
          continue;
        }

        // Coarse on-screen culling using the centroid + max-extent bounding
        // circle. This keeps tight zoom-ins fast (most rings are skipped).
        final approxRadius =
            (globeRadius * maxSin).clamp(8.0, globeRadius + 16.0);
        if (centroid.offset.dx + approxRadius < viewport.left ||
            centroid.offset.dx - approxRadius > viewport.right ||
            centroid.offset.dy + approxRadius < viewport.top ||
            centroid.offset.dy - approxRadius > viewport.bottom) {
          continue;
        }

        items.add(
          _RingRenderItem(
            country: country,
            ring: ring,
            isVisited: isVisited,
            isSelected: isSelected,
            centroid: centroid,
          ),
        );
      }
    }

    // Back-to-front by camera depth so closer rings paint on top of further
    // rings on the rare occasions where they overlap (e.g., overseas
    // territories drawn near a continental neighbour at low zoom).
    items.sort((left, right) =>
        left.centroid.z.compareTo(right.centroid.z));
    return items;
  }

  void _paintRing(
    Canvas canvas, {
    required _RingRenderItem item,
    required GlobeProjector projector,
    required Offset center,
    required double radius,
    required _GlobePalette palette,
    required double defaultStroke,
    required double visitedStroke,
    required double selectedStroke,
  }) {
    final ring = item.ring;
    final verts = _projectRing(ring, projector);

    var anyVisible = false;
    for (final v in verts) {
      if (v.visible) {
        anyVisible = true;
        break;
      }
    }
    if (!anyVisible) {
      return;
    }

    final fillPath = _buildFillPath(verts, center, radius);
    if (fillPath == null) {
      return;
    }

    final isSelected = item.isSelected;
    final isVisited = item.isVisited;

    final fillColor = isSelected
        ? palette.selectedFill
        : (isVisited ? palette.visitedFill : palette.landFill);
    final borderColor = isSelected
        ? palette.selectedBorder
        : (isVisited ? palette.visitedBorder : palette.landBorder);
    final strokeWidth = isSelected
        ? selectedStroke
        : (isVisited ? visitedStroke : defaultStroke);

    final fillPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = fillColor;

    canvas.drawPath(fillPath, fillPaint);

    final borderPath = _buildBorderPath(verts, center, radius);
    if (!borderPath.getBounds().isEmpty) {
      // A thin matching-color underlay smooths the join between fill and
      // stroke at high zoom — without it, antialiasing can leave a 1px
      // ocean-coloured halo at the polygon edge.
      final sealPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth * 1.25
        ..color = fillColor;
      canvas.drawPath(borderPath, sealPaint);

      final borderPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = borderColor;
      canvas.drawPath(borderPath, borderPaint);
    }
  }

  List<GlobeProjectedPoint> _projectRing(
    GlobeRingShape ring,
    GlobeProjector projector,
  ) {
    final points = ring.points;
    final result = List<GlobeProjectedPoint>.filled(
      points.length,
      const GlobeProjectedPoint(x: 0, y: 0, z: 0, offset: Offset.zero),
    );
    for (var i = 0; i < points.length; i++) {
      result[i] = projector.project(points[i]);
    }
    return result;
  }

  /// Build a closed fill path that follows the visible portion of the ring,
  /// connecting consecutive horizon crossings with arcs along the silhouette.
  Path? _buildFillPath(
    List<GlobeProjectedPoint> verts,
    Offset center,
    double radius,
  ) {
    final n = verts.length - 1; // ignore the closing duplicate vertex
    if (n < 3) {
      return null;
    }

    var allVisible = true;
    var anyVisible = false;
    for (var i = 0; i < n; i++) {
      if (verts[i].visible) {
        anyVisible = true;
      } else {
        allVisible = false;
      }
    }
    if (!anyVisible) {
      return null;
    }

    if (allVisible) {
      final path = Path()
        ..moveTo(verts[0].offset.dx, verts[0].offset.dy);
      for (var i = 1; i < n; i++) {
        path.lineTo(verts[i].offset.dx, verts[i].offset.dy);
      }
      path.close();
      return path;
    }

    // Locate a back -> front transition so we can walk the ring linearly.
    var startIdx = -1;
    for (var i = 0; i < n; i++) {
      final prev = verts[(i - 1 + n) % n];
      final curr = verts[i];
      if (curr.visible && !prev.visible) {
        startIdx = i;
        break;
      }
    }

    if (startIdx < 0) {
      // No proper transition (e.g. a single vertex barely poking through).
      return null;
    }

    final path = Path();
    var started = false;
    Offset? firstEnterScreen;
    double? firstEnterAngle;
    double? pendingExitAngle;

    for (var step = 0; step < n; step++) {
      final i = (startIdx + step) % n;
      final j = (i + 1) % n;
      final curr = verts[i];
      final next = verts[j];

      if (curr.visible) {
        if (!started) {
          // We started on a back -> front transition vertex; insert the
          // entry intersection so the polygon begins on the silhouette.
          final prev = verts[(i - 1 + n) % n];
          final entry = computeSilhouettePoint(
            a: prev,
            b: curr,
            center: center,
            radius: radius,
          );
          path.moveTo(entry.screen.dx, entry.screen.dy);
          path.lineTo(curr.offset.dx, curr.offset.dy);
          firstEnterScreen = entry.screen;
          firstEnterAngle = entry.angle;
          started = true;
        } else {
          path.lineTo(curr.offset.dx, curr.offset.dy);
        }

        if (!next.visible) {
          final exit = computeSilhouettePoint(
            a: curr,
            b: next,
            center: center,
            radius: radius,
          );
          path.lineTo(exit.screen.dx, exit.screen.dy);
          pendingExitAngle = exit.angle;
        }
      } else if (next.visible) {
        final entry = computeSilhouettePoint(
          a: curr,
          b: next,
          center: center,
          radius: radius,
        );
        if (pendingExitAngle != null) {
          _appendSilhouetteArc(
            path,
            startAngle: pendingExitAngle,
            endAngle: entry.angle,
            endPoint: entry.screen,
            radius: radius,
          );
          pendingExitAngle = null;
        } else {
          path.moveTo(entry.screen.dx, entry.screen.dy);
          firstEnterScreen ??= entry.screen;
          firstEnterAngle ??= entry.angle;
          started = true;
        }
      }
    }

    if (!started) {
      return null;
    }

    if (pendingExitAngle != null &&
        firstEnterAngle != null &&
        firstEnterScreen != null) {
      _appendSilhouetteArc(
        path,
        startAngle: pendingExitAngle,
        endAngle: firstEnterAngle,
        endPoint: firstEnterScreen,
        radius: radius,
      );
    }

    path.close();
    return path;
  }

  /// Border path with no silhouette arcs — just polygon segments truncated
  /// at the horizon. This keeps the country outline strictly political.
  Path _buildBorderPath(
    List<GlobeProjectedPoint> verts,
    Offset center,
    double radius,
  ) {
    final n = verts.length - 1;
    final path = Path();
    if (n < 2) {
      return path;
    }

    for (var i = 0; i < n; i++) {
      final curr = verts[i];
      final next = verts[(i + 1) % n];
      final currVisible = curr.visible;
      final nextVisible = next.visible;

      if (currVisible && nextVisible) {
        path.moveTo(curr.offset.dx, curr.offset.dy);
        path.lineTo(next.offset.dx, next.offset.dy);
      } else if (currVisible && !nextVisible) {
        final exit = computeSilhouettePoint(
          a: curr,
          b: next,
          center: center,
          radius: radius,
        );
        path.moveTo(curr.offset.dx, curr.offset.dy);
        path.lineTo(exit.screen.dx, exit.screen.dy);
      } else if (!currVisible && nextVisible) {
        final entry = computeSilhouettePoint(
          a: curr,
          b: next,
          center: center,
          radius: radius,
        );
        path.moveTo(entry.screen.dx, entry.screen.dy);
        path.lineTo(next.offset.dx, next.offset.dy);
      }
    }
    return path;
  }

  void _appendSilhouetteArc(
    Path path, {
    required double startAngle,
    required double endAngle,
    required Offset endPoint,
    required double radius,
  }) {
    var diff = endAngle - startAngle;
    while (diff > math.pi) {
      diff -= math.pi * 2;
    }
    while (diff < -math.pi) {
      diff += math.pi * 2;
    }

    // Screen coords have y pointing down: a positive angular delta sweeps
    // clockwise visually, which is also Flutter's `clockwise: true`.
    final clockwise = diff > 0;
    path.arcToPoint(
      endPoint,
      radius: Radius.circular(radius),
      clockwise: clockwise,
      largeArc: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Pins / markers
  // ---------------------------------------------------------------------------

  void _paintMarkers(
    Canvas canvas, {
    required List<_RingRenderItem> renderItems,
    required GlobeProjector projector,
    required double baseRadius,
    required _GlobePalette palette,
  }) {
    // Only mark each country once — pin sits on its largest visible piece.
    final marked = <String>{};
    for (final item in renderItems) {
      final country = item.country;
      final isVisited = item.isVisited;
      final isSelected = item.isSelected;
      if (!isVisited && !isSelected) {
        continue;
      }
      if (!marked.add(country.iso2)) {
        continue;
      }
      final centroid = item.centroid;
      if (centroid.z < 0.02) {
        continue;
      }

      final outerSize = (baseRadius *
              (isSelected ? 0.024 : 0.018))
          .clamp(2.6, 9.0);
      canvas.drawCircle(
        centroid.offset,
        outerSize.toDouble(),
        Paint()
          ..color = isSelected ? palette.selectedPin : palette.visitedPin,
      );
      canvas.drawCircle(
        centroid.offset,
        (outerSize * 0.42).clamp(1.1, 4.0).toDouble(),
        Paint()..color = palette.pinCore,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
}

class _RingRenderItem {
  const _RingRenderItem({
    required this.country,
    required this.ring,
    required this.isVisited,
    required this.isSelected,
    required this.centroid,
  });

  final GlobeCountryShape country;
  final GlobeRingShape ring;
  final bool isVisited;
  final bool isSelected;
  final GlobeProjectedPoint centroid;
}

/// Centralised palette so the visual identity of the globe is in one place.
/// The colors are derived from the active [ColorScheme] so the globe still
/// follows the rest of the app's theme but with a more cinematic, deep-water
/// look that doesn't read as a children's globus.
class _GlobePalette {
  const _GlobePalette({
    required this.oceanHighlight,
    required this.oceanBase,
    required this.oceanDeep,
    required this.atmosphere,
    required this.rim,
    required this.rimLight,
    required this.innerShadow,
    required this.ambientShadow,
    required this.landFill,
    required this.landBorder,
    required this.visitedFill,
    required this.visitedBorder,
    required this.visitedPin,
    required this.selectedFill,
    required this.selectedBorder,
    required this.selectedPin,
    required this.pinCore,
  });

  final Color oceanHighlight;
  final Color oceanBase;
  final Color oceanDeep;
  final Color atmosphere;
  final Color rim;
  final Color rimLight;
  final Color innerShadow;
  final Color ambientShadow;
  final Color landFill;
  final Color landBorder;
  final Color visitedFill;
  final Color visitedBorder;
  final Color visitedPin;
  final Color selectedFill;
  final Color selectedBorder;
  final Color selectedPin;
  final Color pinCore;

  factory _GlobePalette.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    // Cool deep-water gradient — three stops for a sense of depth.
    final oceanHighlight = isDark
        ? const Color(0xFF1E2B3F)
        : const Color(0xFFE7EEF6);
    final oceanBase = isDark
        ? const Color(0xFF13202F)
        : const Color(0xFFCBD9E8);
    final oceanDeep = isDark
        ? const Color(0xFF0A1422)
        : const Color(0xFFA9BCD0);

    return _GlobePalette(
      oceanHighlight: oceanHighlight,
      oceanBase: oceanBase,
      oceanDeep: oceanDeep,
      atmosphere: scheme.primary,
      rim: scheme.outlineVariant,
      rimLight: isDark ? const Color(0xFFCFE3FF) : const Color(0xFFFFFFFF),
      innerShadow: isDark ? Colors.black : const Color(0xFF1B2A3D),
      ambientShadow: scheme.shadow,
      landFill: isDark
          ? const Color(0xFF2A3A4F).withValues(alpha: 0.92)
          : const Color(0xFFF3F1EC).withValues(alpha: 0.96),
      landBorder: isDark
          ? const Color(0xFF7B8FA8).withValues(alpha: 0.60)
          : const Color(0xFF6A788C).withValues(alpha: 0.68),
      visitedFill: scheme.primaryContainer.withValues(alpha: 0.95),
      visitedBorder: scheme.primary.withValues(alpha: 0.95),
      visitedPin: scheme.primary,
      selectedFill: scheme.tertiaryContainer.withValues(alpha: 0.97),
      selectedBorder: scheme.tertiary.withValues(alpha: 0.98),
      selectedPin: scheme.tertiary,
      pinCore: scheme.onPrimary,
    );
  }
}
