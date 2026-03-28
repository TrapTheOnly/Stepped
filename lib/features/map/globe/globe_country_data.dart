import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _degreesToRadians = math.pi / 180.0;
const _lodCount = 2;
const _hiddenTinyCountryIso2 = <String>{'AD', 'LI', 'MC', 'SM', 'VA'};

@immutable
class GlobeGeoPoint {
  GlobeGeoPoint({
    required this.lon,
    required this.lat,
  })  : lonRad = lon * _degreesToRadians,
        latRad = lat * _degreesToRadians,
        sinLon = math.sin(lon * _degreesToRadians),
        cosLon = math.cos(lon * _degreesToRadians),
        sinLat = math.sin(lat * _degreesToRadians),
        cosLat = math.cos(lat * _degreesToRadians);

  final double lon;
  final double lat;
  final double lonRad;
  final double latRad;
  final double sinLon;
  final double cosLon;
  final double sinLat;
  final double cosLat;
}

@immutable
class GlobeCountryShape {
  const GlobeCountryShape({
    required this.iso2,
    required this.name,
    required this.continent,
    required this.lodRings,
    required this.centroid,
    required this.maxAngularDistanceRad,
  });

  final String iso2;
  final String name;
  final String? continent;
  final List<List<List<GlobeGeoPoint>>> lodRings;
  final GlobeGeoPoint centroid;
  final double maxAngularDistanceRad;

  List<List<GlobeGeoPoint>> ringsForLod(int lodLevel) {
    final lod = lodLevel.clamp(0, _lodCount - 1);
    return lodRings[lod];
  }
}

@immutable
class GlobeCountryDataset {
  const GlobeCountryDataset({
    required this.countries,
    required this.byIso2,
  });

  final List<GlobeCountryShape> countries;
  final Map<String, GlobeCountryShape> byIso2;
}

class GlobeCountryDatasetLoader {
  GlobeCountryDatasetLoader._();

  static final Future<GlobeCountryDataset> _cached = _loadFromAssets();

  static Future<GlobeCountryDataset> load() => _cached;

  static Future<GlobeCountryDataset> _loadFromAssets() async {
    final low = await _loadRawCountries(
      assetPath: 'assets/data/countries_200m.geojson',
      source: _GeoSource.naturalEarth110m,
    );
    final high = await _loadRawCountries(
      assetPath: 'assets/data/countries_110m.geojson',
      source: _GeoSource.naturalEarth110m,
    );

    final allIsoCodes = <String>{...low.keys, ...high.keys};
    final builds = <String, _MutableCountry>{};

    for (final iso2 in allIsoCodes) {
      if (_hiddenTinyCountryIso2.contains(iso2)) {
        continue;
      }

      final highRaw = high[iso2];
      final lowRaw = low[iso2] ?? highRaw;
      if (lowRaw == null || lowRaw.rings.isEmpty) {
        continue;
      }
      final name = highRaw?.name ?? lowRaw.name;
      final continent = highRaw?.continent ?? lowRaw.continent;
      final lowRings = lowRaw.rings;
      final highRings = highRaw?.rings ?? lowRings;

      final lodRings = List<List<List<GlobeGeoPoint>>>.generate(
        _lodCount,
        (_) => <List<GlobeGeoPoint>>[],
      );

      for (final ring in lowRings) {
        if (ring.points.length >= 4) {
          lodRings[0].add(List<GlobeGeoPoint>.unmodifiable(ring.points));
        }
      }
      if (lodRings[0].isEmpty) {
        lodRings[0]
            .add(List<GlobeGeoPoint>.unmodifiable(lowRings.first.points));
      }

      for (final ring in highRings) {
        if (ring.points.length >= 4) {
          lodRings[1].add(List<GlobeGeoPoint>.unmodifiable(ring.points));
        }
      }
      if (lodRings[1].isEmpty) {
        lodRings[1]
            .add(List<GlobeGeoPoint>.unmodifiable(highRings.first.points));
      }

      builds[iso2] = _MutableCountry(
        iso2: iso2,
        name: name,
        continent: continent,
        lodRings: lodRings,
      );
    }

    _reattachCrimeaToUkraine(builds);

    final countries = <GlobeCountryShape>[];
    for (final build in builds.values) {
      final topLodRings = _bestReferenceRings(build.lodRings);
      if (topLodRings.isEmpty) {
        continue;
      }

      final centroid = _computeCentroid(topLodRings);
      final maxAngularDistanceRad =
          _computeMaxAngularDistance(centroid, topLodRings);

      countries.add(
        GlobeCountryShape(
          iso2: build.iso2,
          name: build.name,
          continent: build.continent,
          lodRings: List<List<List<GlobeGeoPoint>>>.unmodifiable(
            build.lodRings.map(
              (rings) => List<List<GlobeGeoPoint>>.unmodifiable(rings),
            ),
          ),
          centroid: centroid,
          maxAngularDistanceRad: maxAngularDistanceRad,
        ),
      );
    }

    countries.sort((left, right) => left.iso2.compareTo(right.iso2));

    final byIso2 = <String, GlobeCountryShape>{
      for (final country in countries) country.iso2: country,
    };

    return GlobeCountryDataset(
      countries: List<GlobeCountryShape>.unmodifiable(countries),
      byIso2: Map<String, GlobeCountryShape>.unmodifiable(byIso2),
    );
  }

  static Future<Map<String, _RawCountry>> _loadRawCountries({
    required String assetPath,
    required _GeoSource source,
  }) async {
    final sourceText = await rootBundle.loadString(assetPath);
    final root = jsonDecode(sourceText) as Map<String, dynamic>;
    final features = root['features'] as List<dynamic>? ?? const <dynamic>[];

    final countries = <String, _RawCountry>{};

    for (final feature in features) {
      if (feature is! Map<String, dynamic>) {
        continue;
      }

      final properties = feature['properties'] as Map<String, dynamic>?;
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (properties == null || geometry == null) {
        continue;
      }

      final iso2 = _readIso2(properties, source);
      if (iso2 == null) {
        continue;
      }

      final name = _readName(properties, source, fallback: iso2);
      final continent = _readContinent(properties);

      final rings = _extractBaseRings(geometry)
        ..sort((left, right) => right.areaAbs.compareTo(left.areaAbs));
      if (rings.isEmpty) {
        continue;
      }

      countries[iso2] = _RawCountry(
        iso2: iso2,
        name: name,
        continent: continent,
        rings: rings,
      );
    }

    return countries;
  }

  static String? _readIso2(Map<String, dynamic> properties, _GeoSource source) {
    String? raw;

    switch (source) {
      case _GeoSource.geoCountries:
        raw = (properties['ISO3166-1-Alpha-2'] as String?) ??
            (properties['iso_a2'] as String?);
      case _GeoSource.naturalEarth110m:
        raw = (properties['ISO_A2_EH'] as String?) ??
            (properties['ISO_A2'] as String?) ??
            (properties['WB_A2'] as String?) ??
            (properties['iso_a2_eh'] as String?) ??
            (properties['iso_a2'] as String?) ??
            (properties['wb_a2'] as String?);
    }

    if (raw == null) {
      return null;
    }

    final iso2 = raw.trim().toUpperCase();
    if (iso2.length != 2 || iso2 == '-9' || iso2 == '99' || iso2 == '-99') {
      return null;
    }

    return iso2;
  }

  static String _readName(
    Map<String, dynamic> properties,
    _GeoSource source, {
    required String fallback,
  }) {
    final raw = switch (source) {
      _GeoSource.geoCountries => (properties['name'] as String?) ??
          (properties['ADMIN'] as String?) ??
          (properties['NAME'] as String?),
      _GeoSource.naturalEarth110m => (properties['NAME'] as String?) ??
          (properties['ADMIN'] as String?) ??
          (properties['admin'] as String?) ??
          (properties['name'] as String?),
    };

    final normalized = raw?.trim();
    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }

  static String? _readContinent(Map<String, dynamic> properties) {
    final raw = (properties['CONTINENT'] as String?) ??
        (properties['continent'] as String?) ??
        (properties['REGION_UN'] as String?) ??
        (properties['region_wb'] as String?) ??
        (properties['REGION_WB'] as String?);

    if (raw == null) {
      return null;
    }

    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return switch (normalized.toLowerCase()) {
      'asia' || 'east asia & pacific' || 'middle east & north africa' => 'Asia',
      'europe' || 'europe & central asia' => 'Europe',
      'africa' || 'sub-saharan africa' => 'Africa',
      'north america' => 'North America',
      'south america' => 'South America',
      'oceania' ||
      'australia' ||
      'melanesia' ||
      'micronesia' ||
      'polynesia' =>
        'Oceania',
      'antarctica' => 'Antarctica',
      _ => null,
    };
  }

  static List<List<GlobeGeoPoint>> _bestReferenceRings(
    List<List<List<GlobeGeoPoint>>> lodRings,
  ) {
    for (var lod = _lodCount - 1; lod >= 0; lod--) {
      if (lodRings[lod].isNotEmpty) {
        return lodRings[lod];
      }
    }
    return const <List<GlobeGeoPoint>>[];
  }

  static void _reattachCrimeaToUkraine(Map<String, _MutableCountry> builds) {
    final russia = builds['RU'];
    final ukraine = builds['UA'];
    if (russia == null || ukraine == null) {
      return;
    }

    for (var lod = 0; lod < _lodCount; lod++) {
      final moved = <List<GlobeGeoPoint>>[];
      russia.lodRings[lod].removeWhere((ring) {
        if (_isCrimeaRing(ring)) {
          moved.add(ring);
          return true;
        }
        return false;
      });
      if (moved.isNotEmpty) {
        ukraine.lodRings[lod].addAll(moved);
      }
    }
  }

  static bool _isCrimeaRing(List<GlobeGeoPoint> ring) {
    final openRing = ring.sublist(0, ring.length - 1);
    if (openRing.length < 3) {
      return false;
    }

    var minLon = 180.0;
    var maxLon = -180.0;
    var minLat = 90.0;
    var maxLat = -90.0;

    for (final point in openRing) {
      minLon = math.min(minLon, point.lon);
      maxLon = math.max(maxLon, point.lon);
      minLat = math.min(minLat, point.lat);
      maxLat = math.max(maxLat, point.lat);
    }

    final bboxMatch =
        minLon >= 31.0 && maxLon <= 37.8 && minLat >= 44.0 && maxLat <= 46.8;

    if (!bboxMatch) {
      return false;
    }

    final area = _ringAreaAbs(ring);
    return area > 0.02 && area < 5.5;
  }

  static List<_RawCountryRing> _extractBaseRings(
      Map<String, dynamic> geometry) {
    final type = geometry['type'] as String?;
    final coordinates = geometry['coordinates'];
    final rings = <_RawCountryRing>[];

    if (type == 'Polygon') {
      _addPolygonOuterRing(coordinates, rings);
    } else if (type == 'MultiPolygon' && coordinates is List) {
      for (final polygon in coordinates) {
        _addPolygonOuterRing(polygon, rings);
      }
    }

    return rings;
  }

  static void _addPolygonOuterRing(
    dynamic polygonCoordinates,
    List<_RawCountryRing> destination,
  ) {
    if (polygonCoordinates is! List || polygonCoordinates.isEmpty) {
      return;
    }

    final outerRing = _parseRing(polygonCoordinates.first);
    if (outerRing.length < 4) {
      return;
    }

    destination.add(
      _RawCountryRing(
        points: List<GlobeGeoPoint>.unmodifiable(outerRing),
        areaAbs: _ringAreaAbs(outerRing),
      ),
    );
  }

  static List<GlobeGeoPoint> _parseRing(dynamic rawRing) {
    if (rawRing is! List) {
      return const <GlobeGeoPoint>[];
    }

    final points = <GlobeGeoPoint>[];
    GlobeGeoPoint? previous;
    for (final entry in rawRing) {
      if (entry is! List || entry.length < 2) {
        continue;
      }

      final lonRaw = entry[0];
      final latRaw = entry[1];
      if (lonRaw is! num || latRaw is! num) {
        continue;
      }

      final lon = _normalizeLongitude(lonRaw.toDouble());
      final lat = latRaw.toDouble().clamp(-90.0, 90.0);
      final point = GlobeGeoPoint(lon: lon, lat: lat);

      if (previous != null &&
          (previous.lon - point.lon).abs() < 1e-9 &&
          (previous.lat - point.lat).abs() < 1e-9) {
        continue;
      }

      points.add(point);
      previous = point;
    }

    if (points.length < 3) {
      return const <GlobeGeoPoint>[];
    }

    final first = points.first;
    final last = points.last;
    if ((first.lon - last.lon).abs() > 1e-9 ||
        (first.lat - last.lat).abs() > 1e-9) {
      points.add(GlobeGeoPoint(lon: first.lon, lat: first.lat));
    }

    return points.length >= 4 ? points : const <GlobeGeoPoint>[];
  }

  static GlobeGeoPoint _computeCentroid(List<List<GlobeGeoPoint>> rings) {
    final referenceRing = rings.reduce(
      (left, right) => _ringAreaAbs(left) >= _ringAreaAbs(right) ? left : right,
    );

    final open = referenceRing.sublist(0, referenceRing.length - 1);
    final area = _signedRingArea(open);
    if (area.abs() < 1e-7) {
      return _averagePoint(open);
    }

    var lonSum = 0.0;
    var latSum = 0.0;
    for (var i = 0; i < open.length; i++) {
      final current = open[i];
      final next = open[(i + 1) % open.length];
      final factor = (current.lon * next.lat) - (next.lon * current.lat);
      lonSum += (current.lon + next.lon) * factor;
      latSum += (current.lat + next.lat) * factor;
    }

    final scale = 1.0 / (6.0 * area);
    return GlobeGeoPoint(
      lon: _normalizeLongitude(lonSum * scale),
      lat: (latSum * scale).clamp(-90.0, 90.0),
    );
  }

  static double _computeMaxAngularDistance(
    GlobeGeoPoint centroid,
    List<List<GlobeGeoPoint>> rings,
  ) {
    final referenceRing = rings.reduce(
      (left, right) => _ringAreaAbs(left) >= _ringAreaAbs(right) ? left : right,
    );

    var maxDistance = 0.0;
    for (final point in referenceRing) {
      final distance = _angularDistanceRad(centroid, point);
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }

    return math.max(maxDistance, 0.08);
  }

  static GlobeGeoPoint _averagePoint(List<GlobeGeoPoint> points) {
    if (points.isEmpty) {
      return GlobeGeoPoint(lon: 0, lat: 0);
    }

    var lonSum = 0.0;
    var latSum = 0.0;
    for (final point in points) {
      lonSum += point.lon;
      latSum += point.lat;
    }

    return GlobeGeoPoint(
      lon: _normalizeLongitude(lonSum / points.length),
      lat: (latSum / points.length).clamp(-90.0, 90.0),
    );
  }

  static double _ringAreaAbs(List<GlobeGeoPoint> ring) {
    return _signedRingArea(ring.sublist(0, ring.length - 1)).abs();
  }

  static double _signedRingArea(List<GlobeGeoPoint> ring) {
    var sum = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final current = ring[i];
      final next = ring[(i + 1) % ring.length];
      sum += (current.lon * next.lat) - (next.lon * current.lat);
    }
    return sum / 2.0;
  }

  static double _angularDistanceRad(GlobeGeoPoint first, GlobeGeoPoint second) {
    final deltaLon = first.lonRad - second.lonRad;
    final cosine = (first.sinLat * second.sinLat) +
        (first.cosLat * second.cosLat * math.cos(deltaLon));
    return math.acos(cosine.clamp(-1.0, 1.0));
  }

  static double _normalizeLongitude(double lon) {
    var normalized = lon;
    while (normalized < -180.0) {
      normalized += 360.0;
    }
    while (normalized > 180.0) {
      normalized -= 360.0;
    }
    return normalized;
  }
}

enum _GeoSource {
  geoCountries,
  naturalEarth110m,
}

class _RawCountry {
  const _RawCountry({
    required this.iso2,
    required this.name,
    required this.continent,
    required this.rings,
  });

  final String iso2;
  final String name;
  final String? continent;
  final List<_RawCountryRing> rings;
}

class _RawCountryRing {
  const _RawCountryRing({
    required this.points,
    required this.areaAbs,
  });

  final List<GlobeGeoPoint> points;
  final double areaAbs;
}

class _MutableCountry {
  const _MutableCountry({
    required this.iso2,
    required this.name,
    required this.continent,
    required this.lodRings,
  });

  final String iso2;
  final String name;
  final String? continent;
  final List<List<List<GlobeGeoPoint>>> lodRings;
}
