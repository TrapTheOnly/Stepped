import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'globe_country_data.dart';

/// A geo point lifted into the camera's coordinate space (unit sphere) with a
/// pre-computed screen projection. The point sits on the unit sphere when
/// [GlobeProjector.project] returns it, so [x]² + [y]² + [z]² ≈ 1.
@immutable
class GlobeProjectedPoint {
  const GlobeProjectedPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.offset,
  });

  /// Camera-space coordinates on the unit sphere.
  final double x;
  final double y;
  final double z;

  /// Screen-space projection (`y` is mirrored, the camera looks at +Z).
  final Offset offset;

  /// True when the point lies on the front-facing hemisphere.
  bool get visible => z > 0;
}

/// Static helpers used by both the renderer and the camera animation logic.
class GlobeProjection {
  const GlobeProjection._();

  static GlobeProjector projector({
    required double rotation,
    required double pitch,
    required Offset center,
    required double radius,
  }) {
    return GlobeProjector(
      center: center,
      radius: radius,
      sinRotation: math.sin(rotation),
      cosRotation: math.cos(rotation),
      sinPitch: math.sin(pitch),
      cosPitch: math.cos(pitch),
    );
  }

  static GlobeProjectedPoint project({
    required GlobeGeoPoint point,
    required double rotation,
    required double pitch,
    required Offset center,
    required double radius,
  }) {
    return projector(
      rotation: rotation,
      pitch: pitch,
      center: center,
      radius: radius,
    ).project(point);
  }

  static double normalizeAngle(double angle) {
    var normalized = angle;
    while (normalized > math.pi) {
      normalized -= math.pi * 2;
    }
    while (normalized < -math.pi) {
      normalized += math.pi * 2;
    }
    return normalized;
  }

  static double nearestAngle({
    required double current,
    required double target,
  }) {
    final delta = normalizeAngle(target - current);
    return current + delta;
  }
}

/// Stateless projector that maps geographic coordinates onto camera space and
/// from there to the 2D screen. All trig values for rotation/pitch are
/// precomputed once per frame so the inner projection loop is a handful of
/// multiplies and adds — perfect for tight per-vertex work in [CustomPainter].
class GlobeProjector {
  const GlobeProjector({
    required this.center,
    required this.radius,
    required this.sinRotation,
    required this.cosRotation,
    required this.sinPitch,
    required this.cosPitch,
  });

  final Offset center;
  final double radius;
  final double sinRotation;
  final double cosRotation;
  final double sinPitch;
  final double cosPitch;

  /// Project a [GlobeGeoPoint] into camera + screen space.
  GlobeProjectedPoint project(GlobeGeoPoint point) {
    // Rotate around the polar axis (longitude).
    final sinLon = (point.sinLon * cosRotation) + (point.cosLon * sinRotation);
    final cosLon = (point.cosLon * cosRotation) - (point.sinLon * sinRotation);

    // Sphere coordinates with rotation applied.
    final x = point.cosLat * sinLon;
    final yBase = point.sinLat;
    final zBase = point.cosLat * cosLon;

    // Tilt the camera (pitch).
    final y = (yBase * cosPitch) - (zBase * sinPitch);
    final z = (yBase * sinPitch) + (zBase * cosPitch);

    return GlobeProjectedPoint(
      x: x,
      y: y,
      z: z,
      offset: Offset(
        center.dx + (x * radius),
        center.dy - (y * radius),
      ),
    );
  }

  /// Project an arbitrary 3D camera-space point onto the screen. Used after
  /// horizon-edge interpolation, where the resulting point is constructed
  /// rather than projected from a [GlobeGeoPoint].
  Offset projectXY(double x, double y) {
    return Offset(center.dx + (x * radius), center.dy - (y * radius));
  }
}

/// A point on the visible silhouette of the globe — the result of intersecting
/// a polygon edge with the camera horizon plane. Always lies exactly on the
/// disc edge in screen space.
@immutable
class GlobeSilhouettePoint {
  const GlobeSilhouettePoint({
    required this.screen,
    required this.angle,
  });

  /// Screen position on the disc edge.
  final Offset screen;

  /// Angle (radians) measured around the screen-space disc center. Used to
  /// drive the [Path.arcToPoint] connecting consecutive horizon crossings.
  final double angle;
}

/// Compute the screen-space silhouette point where the great-circle "edge"
/// from [a] to [b] (with one front-facing and one back-facing endpoint)
/// crosses the horizon plane.
///
/// We linearly interpolate the camera-space coordinates so the intersection
/// has `z = 0`, then renormalise the resulting `(x, y)` to lie exactly on
/// the unit circle. This guarantees the point sits on the visible globe
/// silhouette in screen space, which lets the renderer connect consecutive
/// crossings with `arcToPoint` along the disc edge — eliminating the chord
/// artefacts that show up when polygons just close with straight lines.
GlobeSilhouettePoint computeSilhouettePoint({
  required GlobeProjectedPoint a,
  required GlobeProjectedPoint b,
  required Offset center,
  required double radius,
}) {
  final denom = a.z - b.z;
  // The function is only meant to be called with one visible and one
  // hidden endpoint, so denom should be safely non-zero.
  final t = denom.abs() < 1e-9 ? 0.5 : a.z / denom;
  final ix = a.x + t * (b.x - a.x);
  final iy = a.y + t * (b.y - a.y);

  final length = math.sqrt((ix * ix) + (iy * iy));
  // Fallback in the degenerate case where both points sit very close to the
  // pole of the silhouette circle.
  final nx = length > 1e-9 ? ix / length : 1.0;
  final ny = length > 1e-9 ? iy / length : 0.0;

  final screen = Offset(
    center.dx + (nx * radius),
    center.dy - (ny * radius),
  );
  // Screen-space angle (y is flipped). atan2 handles the wraparound for us.
  final angle = math.atan2(screen.dy - center.dy, screen.dx - center.dx);

  return GlobeSilhouettePoint(screen: screen, angle: angle);
}
