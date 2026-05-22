import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'globe_country_data.dart';
import 'globe_projection.dart';

const globeTinyRingFastPathThreshold = 4.6;

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
    final defaultStroke = (strokeBase * 0.0035).clamp(0.35, 0.55);
    final visitedStroke = (strokeBase * 0.0070).clamp(0.65, 0.90);
    final selectedStroke = (strokeBase * 0.0080).clamp(0.80, 1.20);
    final preparedItems = _prepareRenderItems(
      renderQueue,
      projector: projector,
      center: center,
      radius: globeRadius,
    );

    for (final item in preparedItems) {
      _paintRingFill(
        canvas,
        item: item,
        palette: palette,
      );
    }

    for (final item in preparedItems) {
      _paintRingBaseBorder(
        canvas,
        item: item,
        palette: palette,
        defaultStroke: defaultStroke,
        visitedStroke: visitedStroke,
        selectedStroke: selectedStroke,
      );
    }

    for (final item in preparedItems) {
      if (!item.renderItem.isVisited || item.renderItem.isSelected) {
        continue;
      }
      _paintRingStateOverlay(
        canvas,
        item: item,
        palette: palette,
        visitedStroke: visitedStroke,
        selectedStroke: selectedStroke,
      );
    }

    for (final item in preparedItems) {
      if (!item.renderItem.isSelected) {
        continue;
      }
      _paintRingStateOverlay(
        canvas,
        item: item,
        palette: palette,
        visitedStroke: visitedStroke,
        selectedStroke: selectedStroke,
      );
    }

    _paintMarkers(
      canvas,
      renderItems: renderQueue,
      baseRadius: baseRadius,
      palette: palette,
      showVisitedMarkers: lodLevel >= 1,
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
    // Inner glow — tight to sphere edge, warm moss tint for rim separation.
    final innerRadius = globeRadius * 1.025;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final innerPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        innerRadius,
        <Color>[
          palette.atmosphereInner.withValues(alpha: 0.0),
          palette.atmosphereInner.withValues(alpha: 0.08),
          palette.atmosphereInner.withValues(alpha: 0.0),
        ],
        <double>[0.89, 0.96, 1.0],
      );
    canvas.drawRect(innerRect, innerPaint);

    // Outer halo — soft cool diffusion, wider overshoot.
    final outerRadius = globeRadius * 1.10;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final outerPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        outerRadius,
        <Color>[
          palette.atmosphereOuter.withValues(alpha: 0.0),
          palette.atmosphereOuter.withValues(alpha: 0.035),
          palette.atmosphereOuter.withValues(alpha: 0.0),
        ],
        <double>[0.83, 0.94, 1.0],
      );
    canvas.drawRect(outerRect, outerPaint);
  }

  void _paintSphereSurface(
    Canvas canvas,
    Offset center,
    double globeRadius,
    _GlobePalette palette,
  ) {
    // Base ocean fill — soft radial gradient anchored in nightForest.
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

    // Subtle warm rim light — tinted with mossSoft to tie into app palette.
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
            palette.rimLight.withValues(alpha: 0.16),
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
    final rimWidth =
        math.max(1.0, baseRadius * 0.008).clamp(1.0, 3.0).toDouble();

    // Sweep gradient: upper-left catches light (mossSoft tint),
    // lower-right falls into shadow (outlineVariant).
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimWidth
      ..shader = ui.Gradient.sweep(
        center,
        <Color>[
          palette.rimDark.withValues(alpha: 0.10),
          palette.rimHighlight.withValues(alpha: 0.38),
          palette.rimHighlight.withValues(alpha: 0.38),
          palette.rimDark.withValues(alpha: 0.10),
          palette.rimShadow.withValues(alpha: 0.24),
          palette.rimShadow.withValues(alpha: 0.24),
          palette.rimDark.withValues(alpha: 0.10),
        ],
        <double>[0.0, 0.08, 0.28, 0.42, 0.58, 0.78, 1.0],
      );
    canvas.drawCircle(center, globeRadius, rimPaint);
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
        final projectedRadius = globeRadius * maxSin;

        // Cull rings that are entirely on the back hemisphere. We allow a
        // tiny epsilon so rings that *just* touch the horizon still draw.
        if (centroid.z + maxSin < -0.02) {
          continue;
        }

        // Coarse on-screen culling using the centroid + max-extent bounding
        // circle. This keeps tight zoom-ins fast (most rings are skipped).
        final approxRadius =
            projectedRadius.clamp(8.0, globeRadius + 16.0).toDouble();
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
            projectedRadius: projectedRadius,
          ),
        );
      }
    }

    // Back-to-front by camera depth so closer rings paint on top of further
    // rings on the rare occasions where they overlap (e.g., overseas
    // territories drawn near a continental neighbour at low zoom).
    items.sort((left, right) => left.centroid.z.compareTo(right.centroid.z));
    return items;
  }

  List<_PreparedRingRenderItem> _prepareRenderItems(
    List<_RingRenderItem> renderItems, {
    required GlobeProjector projector,
    required Offset center,
    required double radius,
  }) {
    final preparedItems = <_PreparedRingRenderItem>[];
    for (final item in renderItems) {
      if (_shouldUseTinyRingFastPath(item)) {
        final dotRadius = item.projectedRadius
            .clamp(item.isSelected ? 3.2 : 2.2, item.isSelected ? 8.0 : 6.0)
            .toDouble();
        preparedItems.add(
          _PreparedRingRenderItem(
            renderItem: item,
            fillPath: null,
            borderPath: null,
            dotRadius: dotRadius,
          ),
        );
        continue;
      }

      final verts = _projectRing(item.ring, projector);
      var anyVisible = false;
      for (final v in verts) {
        if (v.visible) {
          anyVisible = true;
          break;
        }
      }
      if (!anyVisible) {
        continue;
      }

      final fillPath = _buildFillPath(verts, center, radius);
      if (fillPath == null) {
        continue;
      }

      final borderPath = _buildBorderPath(verts, center, radius);
      preparedItems.add(
        _PreparedRingRenderItem(
          renderItem: item,
          fillPath: fillPath,
          borderPath: borderPath.getBounds().isEmpty ? null : borderPath,
          dotRadius: null,
        ),
      );
    }
    return preparedItems;
  }

  bool _shouldUseTinyRingFastPath(_RingRenderItem item) {
    return item.centroid.z > 0 &&
        item.projectedRadius <= globeTinyRingFastPathThreshold;
  }

  Color _fillColorForState({
    required _GlobePalette palette,
    required bool isVisited,
    required bool isSelected,
  }) {
    if (isSelected && isVisited) {
      return palette.selectedVisitedFill;
    }
    if (isSelected) {
      return palette.selectedFill;
    }
    if (isVisited) {
      return palette.visitedFill;
    }
    return palette.landFill;
  }

  Color _borderColorForState({
    required _GlobePalette palette,
    required bool isVisited,
    required bool isSelected,
  }) {
    if (isSelected && isVisited) {
      return palette.selectedVisitedBorder;
    }
    if (isSelected) {
      return palette.selectedBorder;
    }
    if (isVisited) {
      return palette.visitedBorder;
    }
    return palette.landBorder;
  }

  double _strokeWidthForState({
    required bool isVisited,
    required bool isSelected,
    required double defaultStroke,
    required double visitedStroke,
    required double selectedStroke,
  }) {
    if (isSelected) {
      return selectedStroke;
    }
    if (isVisited) {
      return visitedStroke;
    }
    return defaultStroke;
  }

  void _paintRingFill(
    Canvas canvas, {
    required _PreparedRingRenderItem item,
    required _GlobePalette palette,
  }) {
    final renderItem = item.renderItem;
    final isSelected = renderItem.isSelected;
    final isVisited = renderItem.isVisited;

    final fillColor = _fillColorForState(
      palette: palette,
      isVisited: isVisited,
      isSelected: isSelected,
    );

    final dotRadius = item.dotRadius;
    if (dotRadius != null) {
      if (isSelected) {
        canvas.drawCircle(
          renderItem.centroid.offset,
          dotRadius + 2.0,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.fill
            ..color =
                isVisited ? palette.selectedVisitedGlow : palette.selectedGlow
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
        );
      }

      canvas.drawCircle(
        renderItem.centroid.offset,
        dotRadius,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..color = fillColor,
      );
      return;
    }

    final fillPath = item.fillPath;
    if (fillPath == null) {
      return;
    }

    if (isSelected) {
      final glowPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..color =
            (isVisited ? palette.selectedVisitedGlow : palette.selectedGlow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.4);
      canvas.drawPath(fillPath, glowPaint);
    }

    final fillPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawPath(fillPath, fillPaint);
  }

  void _paintRingBaseBorder(
    Canvas canvas, {
    required _PreparedRingRenderItem item,
    required _GlobePalette palette,
    required double defaultStroke,
    required double visitedStroke,
    required double selectedStroke,
  }) {
    final renderItem = item.renderItem;
    final isSelected = renderItem.isSelected;
    final isVisited = renderItem.isVisited;
    final fillColor = _fillColorForState(
      palette: palette,
      isVisited: isVisited,
      isSelected: isSelected,
    );
    final strokeWidth = _strokeWidthForState(
      isVisited: isVisited,
      isSelected: isSelected,
      defaultStroke: defaultStroke,
      visitedStroke: visitedStroke,
      selectedStroke: selectedStroke,
    );

    final dotRadius = item.dotRadius;
    if (dotRadius != null) {
      canvas.drawCircle(
        renderItem.centroid.offset,
        dotRadius,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.min(strokeWidth, dotRadius * 0.65)
          ..color = palette.landBorder,
      );
      return;
    }

    final borderPath = item.borderPath;
    if (borderPath == null) {
      return;
    }

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
      ..color = palette.landBorder;
    canvas.drawPath(borderPath, borderPaint);
  }

  void _paintRingStateOverlay(
    Canvas canvas, {
    required _PreparedRingRenderItem item,
    required _GlobePalette palette,
    required double visitedStroke,
    required double selectedStroke,
  }) {
    final renderItem = item.renderItem;
    final isSelected = renderItem.isSelected;
    final isVisited = renderItem.isVisited;
    final strokeWidth = isSelected ? selectedStroke : visitedStroke;
    final borderColor = _borderColorForState(
      palette: palette,
      isVisited: isVisited,
      isSelected: isSelected,
    );

    final dotRadius = item.dotRadius;
    if (dotRadius != null) {
      canvas.drawCircle(
        renderItem.centroid.offset,
        dotRadius,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.min(strokeWidth, dotRadius * 0.65)
          ..color = borderColor,
      );
      return;
    }

    final borderPath = item.borderPath;
    if (borderPath == null) {
      return;
    }

    if (isVisited && !isSelected) {
      final visitedGlowPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth * 1.45
        ..color = palette.visitedGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.35);
      canvas.drawPath(borderPath, visitedGlowPaint);
    }

    final borderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = borderColor;
    canvas.drawPath(borderPath, borderPaint);

    if (isVisited && !isSelected) {
      final reliefPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth * 0.62
        ..color = palette.visitedHighlight;
      canvas.drawPath(borderPath, reliefPaint);
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
      final path = Path()..moveTo(verts[0].offset.dx, verts[0].offset.dy);
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
  // Markers — luminous dots
  // ---------------------------------------------------------------------------

  void _paintMarkers(
    Canvas canvas, {
    required List<_RingRenderItem> renderItems,
    required double baseRadius,
    required _GlobePalette palette,
    required bool showVisitedMarkers,
  }) {
    final markerItems = <String, _RingRenderItem>{};
    for (final item in renderItems) {
      final country = item.country;
      final isVisited = item.isVisited;
      final isSelected = item.isSelected;
      if (!isVisited && !isSelected) {
        continue;
      }
      if (isVisited && !showVisitedMarkers) {
        continue;
      }
      final centroid = item.centroid;
      if (centroid.z < 0.02) {
        continue;
      }

      final previous = markerItems[country.iso2];
      if (previous == null || _isBetterMarkerItem(item, previous)) {
        markerItems[country.iso2] = item;
      }
    }

    for (final item in markerItems.values) {
      final isSelected = item.isSelected;
      final centroid = item.centroid;
      final markerColor = isSelected ? palette.selectedDot : palette.visitedDot;
      final coreRadius = (baseRadius * (isSelected ? 0.0065 : 0.0045))
          .clamp(2.0, 5.0)
          .toDouble();
      final glowRadius = coreRadius * (isSelected ? 2.65 : 2.25);

      // Soft radial glow underlay.
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          centroid.offset,
          glowRadius,
          <Color>[
            markerColor.withValues(alpha: isSelected ? 0.40 : 0.28),
            markerColor.withValues(alpha: 0.0),
          ],
        );
      canvas.drawCircle(centroid.offset, glowRadius, glowPaint);

      // Crisp core.
      canvas.drawCircle(
        centroid.offset,
        coreRadius,
        Paint()..color = markerColor,
      );
    }
  }

  bool _isBetterMarkerItem(_RingRenderItem item, _RingRenderItem previous) {
    final radiusDelta = item.projectedRadius - previous.projectedRadius;
    if (radiusDelta.abs() > 0.75) {
      return radiusDelta > 0;
    }
    return item.centroid.z > previous.centroid.z;
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
    required this.projectedRadius,
  });

  final GlobeCountryShape country;
  final GlobeRingShape ring;
  final bool isVisited;
  final bool isSelected;
  final GlobeProjectedPoint centroid;
  final double projectedRadius;
}

class _PreparedRingRenderItem {
  const _PreparedRingRenderItem({
    required this.renderItem,
    required this.fillPath,
    required this.borderPath,
    required this.dotRadius,
  });

  final _RingRenderItem renderItem;
  final Path? fillPath;
  final Path? borderPath;
  final double? dotRadius;
}

/// Centralised palette for the globe's visual identity.
///
/// Ocean stays dimensional in both themes, land uses warm earth tones, and
/// visited countries get a quiet fill instead of relying on outlines.
class _GlobePalette {
  const _GlobePalette({
    required this.oceanHighlight,
    required this.oceanBase,
    required this.oceanDeep,
    required this.atmosphereInner,
    required this.atmosphereOuter,
    required this.rimHighlight,
    required this.rimShadow,
    required this.rimDark,
    required this.rimLight,
    required this.innerShadow,
    required this.ambientShadow,
    required this.landFill,
    required this.landBorder,
    required this.visitedFill,
    required this.visitedBorder,
    required this.visitedHighlight,
    required this.visitedGlow,
    required this.visitedDot,
    required this.selectedBorder,
    required this.selectedVisitedBorder,
    required this.selectedGlow,
    required this.selectedVisitedGlow,
    required this.selectedFill,
    required this.selectedVisitedFill,
    required this.selectedDot,
  });

  final Color oceanHighlight;
  final Color oceanBase;
  final Color oceanDeep;
  final Color atmosphereInner;
  final Color atmosphereOuter;
  final Color rimHighlight;
  final Color rimShadow;
  final Color rimDark;
  final Color rimLight;
  final Color innerShadow;
  final Color ambientShadow;
  final Color landFill;
  final Color landBorder;
  final Color visitedFill;
  final Color visitedBorder;
  final Color visitedHighlight;
  final Color visitedGlow;
  final Color visitedDot;
  final Color selectedBorder;
  final Color selectedVisitedBorder;
  final Color selectedGlow;
  final Color selectedVisitedGlow;
  final Color selectedFill;
  final Color selectedVisitedFill;
  final Color selectedDot;

  factory _GlobePalette.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    // Ocean — dark green-gray in dark mode, muted slate in light mode.
    final oceanHighlight =
        isDark ? const Color(0xFF24382F) : const Color(0xFFD9DFD6);
    final oceanBase =
        isDark ? const Color(0xFF14251D) : const Color(0xFFB7C6C2);
    final oceanDeep =
        isDark ? const Color(0xFF09110E) : const Color(0xFF7F9491);

    // Land — cream and warm gold from the logo, softened for map readability.
    final landFill = isDark
        ? const Color(0xFF2A2A20).withValues(alpha: 0.96)
        : const Color(0xFFEBDDC4).withValues(alpha: 0.98);
    final landBorder = isDark
        ? const Color(0xFF77674F).withValues(alpha: 0.42)
        : const Color(0xFF897C68).withValues(alpha: 0.52);

    final forest = const Color(0xFF254333);
    final warmGold = const Color(0xFFD4B88B);
    final creamHighlight = const Color(0xFFEBD7B3);
    final slateBlue = const Color(0xFF3E606B);

    final selectedColor = isDark ? warmGold : forest;
    final visitedFill = isDark
        ? const Color(0xFF254333).withValues(alpha: 0.92)
        : const Color(0xFFC8D2C6).withValues(alpha: 0.96);
    final selectedFill = isDark
        ? const Color(0xFF5F4F31).withValues(alpha: 0.94)
        : const Color(0xFFD4B88B).withValues(alpha: 0.95);
    final selectedVisitedFill = isDark
        ? const Color(0xFF315541).withValues(alpha: 0.96)
        : const Color(0xFFB9C8B9).withValues(alpha: 0.98);

    // Visited: distinct fill first, then a quiet forest edge.
    final visitedBorder = (isDark ? creamHighlight : forest)
        .withValues(alpha: isDark ? 0.58 : 0.62);
    final visitedHighlight =
        creamHighlight.withValues(alpha: isDark ? 0.16 : 0.20);
    final visitedGlow = forest.withValues(alpha: isDark ? 0.18 : 0.12);

    // Selected: gold focus for unvisited, forest fill plus gold edge for visited.
    final selectedBorder =
        selectedColor.withValues(alpha: isDark ? 0.84 : 0.78);
    final selectedVisitedBorder =
        warmGold.withValues(alpha: isDark ? 0.86 : 0.76);
    final selectedGlow = selectedColor.withValues(alpha: isDark ? 0.18 : 0.20);
    final selectedVisitedGlow = forest.withValues(alpha: isDark ? 0.18 : 0.16);

    // Markers — low-glow pins used only after the globe reaches detail zoom.
    final visitedDot = (isDark ? creamHighlight : forest)
        .withValues(alpha: isDark ? 0.78 : 0.82);
    final selectedDot = warmGold.withValues(alpha: isDark ? 0.88 : 0.84);

    // Atmosphere — inner forest warmth, outer slate-blue coolness.
    final atmosphereInner = isDark ? creamHighlight : forest;
    final atmosphereOuter = slateBlue;

    // Rim — directional light gradient.
    final rimHighlight = isDark ? creamHighlight : forest;
    final rimShadow = isDark ? scheme.outlineVariant : const Color(0xFF60736D);
    final rimDark = isDark ? const Color(0xFF07100E) : const Color(0xFF78908A);

    return _GlobePalette(
      oceanHighlight: oceanHighlight,
      oceanBase: oceanBase,
      oceanDeep: oceanDeep,
      atmosphereInner: atmosphereInner,
      atmosphereOuter: atmosphereOuter,
      rimHighlight: rimHighlight,
      rimShadow: rimShadow,
      rimDark: rimDark,
      rimLight: isDark ? creamHighlight : const Color(0xFFF3EAD8),
      innerShadow: isDark ? Colors.black : const Color(0xFF1B2A3D),
      ambientShadow: scheme.shadow,
      landFill: landFill,
      landBorder: landBorder,
      visitedFill: visitedFill,
      visitedBorder: visitedBorder,
      visitedHighlight: visitedHighlight,
      visitedGlow: visitedGlow,
      visitedDot: visitedDot,
      selectedBorder: selectedBorder,
      selectedVisitedBorder: selectedVisitedBorder,
      selectedGlow: selectedGlow,
      selectedVisitedGlow: selectedVisitedGlow,
      selectedFill: selectedFill,
      selectedVisitedFill: selectedVisitedFill,
      selectedDot: selectedDot,
    );
  }
}
