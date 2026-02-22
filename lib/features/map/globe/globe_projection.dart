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

  static GlobeProjectedPoint project({
    required GlobeGeoPoint point,
    required double rotation,
    required double pitch,
    required Offset center,
    required double radius,
  }) {
    final lon = point.lonRad + rotation;
    final x = point.cosLat * math.sin(lon);
    final yBase = point.sinLat;
    final zBase = point.cosLat * math.cos(lon);

    final sinPitch = math.sin(pitch);
    final cosPitch = math.cos(pitch);

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
