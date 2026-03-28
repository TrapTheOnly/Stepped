import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'globe_country_data.dart';

class GlobeProjectedPoint {
  const GlobeProjectedPoint({
    required this.offset,
    required this.depth,
  });

  final Offset offset;
  final double depth;

  bool get visible => depth > 0;
}

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

  GlobeProjectedPoint project(GlobeGeoPoint point) {
    final sinLon = (point.sinLon * cosRotation) + (point.cosLon * sinRotation);
    final cosLon = (point.cosLon * cosRotation) - (point.sinLon * sinRotation);
    final x = point.cosLat * sinLon;
    final yBase = point.sinLat;
    final zBase = point.cosLat * cosLon;

    final y = (yBase * cosPitch) - (zBase * sinPitch);
    final z = (yBase * sinPitch) + (zBase * cosPitch);

    return GlobeProjectedPoint(
      offset: Offset(
        center.dx + (x * radius),
        center.dy - (y * radius),
      ),
      depth: z,
    );
  }
}
