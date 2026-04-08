import '../../data/db/app_db_models.dart';

enum TripListStatusFilter {
  any('Any'),
  upcoming('Upcoming'),
  ongoing('Ongoing'),
  past('Past');

  const TripListStatusFilter(this.label);
  final String label;
}

enum TripListSourceFilter {
  any('Any'),
  manual('Manual'),
  wishlist('From wishlist');

  const TripListSourceFilter(this.label);
  final String label;
}

class TripsSearchFilters {
  const TripsSearchFilters({
    this.query = '',
    this.status = TripListStatusFilter.any,
    this.source = TripListSourceFilter.any,
    this.country,
    this.year,
    this.dateRange,
  });

  final String query;
  final TripListStatusFilter status;
  final TripListSourceFilter source;
  final String? country;
  final int? year;
  final DateTimeRangeValue? dateRange;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      status != TripListStatusFilter.any ||
      source != TripListSourceFilter.any ||
      country != null ||
      year != null ||
      dateRange != null;

  TripsSearchFilters copyWith({
    String? query,
    TripListStatusFilter? status,
    TripListSourceFilter? source,
    Object? country = _sentinel,
    Object? year = _sentinel,
    Object? dateRange = _sentinel,
  }) {
    return TripsSearchFilters(
      query: query ?? this.query,
      status: status ?? this.status,
      source: source ?? this.source,
      country:
          identical(country, _sentinel) ? this.country : country as String?,
      year: identical(year, _sentinel) ? this.year : year as int?,
      dateRange: identical(dateRange, _sentinel)
          ? this.dateRange
          : dateRange as DateTimeRangeValue?,
    );
  }

  TripsSearchFilters cleared({String? query}) {
    return TripsSearchFilters(query: query ?? this.query);
  }
}

class DateTimeRangeValue {
  const DateTimeRangeValue({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

List<TripRecord> applyTripSearchFilters(
  List<TripRecord> trips,
  TripsSearchFilters filters, {
  DateTime? now,
}) {
  final effectiveNow = _dateOnly(now ?? DateTime.now());
  final normalizedQuery = filters.query.trim().toLowerCase();

  return trips.where((trip) {
    if (normalizedQuery.isNotEmpty) {
      final searchHaystack = <String>[
        trip.countryName,
        trip.countryCode,
        trip.cities,
        trip.notes ?? '',
      ].join(' ').toLowerCase();
      if (!searchHaystack.contains(normalizedQuery)) {
        return false;
      }
    }

    if (filters.country != null && trip.countryName != filters.country) {
      return false;
    }

    if (filters.source != TripListSourceFilter.any) {
      final fromWishlist = trip.sourceWishlistItemId != null;
      if (filters.source == TripListSourceFilter.manual && fromWishlist) {
        return false;
      }
      if (filters.source == TripListSourceFilter.wishlist && !fromWishlist) {
        return false;
      }
    }

    final start = _dateFromEpochMillis(trip.startDate);
    final end = _dateFromEpochMillis(trip.endDate);

    if (filters.status != TripListStatusFilter.any &&
        _tripStatusFor(start: start, end: end, now: effectiveNow) !=
            filters.status) {
      return false;
    }

    if (filters.year != null &&
        !_rangeTouchesYear(start: start, end: end, year: filters.year!)) {
      return false;
    }

    if (filters.dateRange != null &&
        !_rangesOverlap(
          start,
          end,
          filters.dateRange!.start,
          filters.dateRange!.end,
        )) {
      return false;
    }

    return true;
  }).toList(growable: false);
}

List<String> tripCountryFilterOptions(List<TripRecord> trips) {
  final countries = trips
      .map((trip) => trip.countryName.trim())
      .where((country) => country.isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
  return countries;
}

List<int> tripYearFilterOptions(List<TripRecord> trips) {
  final years = <int>{};
  for (final trip in trips) {
    final start = _dateFromEpochMillis(trip.startDate);
    final end = _dateFromEpochMillis(trip.endDate);
    for (var year = start.year; year <= end.year; year++) {
      years.add(year);
    }
  }
  return years.toList(growable: false)..sort((a, b) => b.compareTo(a));
}

TripListStatusFilter tripListStatusForRecord(TripRecord trip, {DateTime? now}) {
  return _tripStatusFor(
    start: _dateFromEpochMillis(trip.startDate),
    end: _dateFromEpochMillis(trip.endDate),
    now: _dateOnly(now ?? DateTime.now()),
  );
}

TripListStatusFilter _tripStatusFor({
  required DateTime start,
  required DateTime end,
  required DateTime now,
}) {
  if (end.isBefore(now)) {
    return TripListStatusFilter.past;
  }
  if (start.isAfter(now)) {
    return TripListStatusFilter.upcoming;
  }
  return TripListStatusFilter.ongoing;
}

bool _rangeTouchesYear({
  required DateTime start,
  required DateTime end,
  required int year,
}) {
  final yearStart = DateTime(year);
  final yearEnd = DateTime(year, 12, 31);
  return _rangesOverlap(start, end, yearStart, yearEnd);
}

bool _rangesOverlap(
  DateTime startA,
  DateTime endA,
  DateTime startB,
  DateTime endB,
) {
  final normalizedStartA = _dateOnly(startA);
  final normalizedEndA = _dateOnly(endA);
  final normalizedStartB = _dateOnly(startB);
  final normalizedEndB = _dateOnly(endB);
  return !normalizedEndA.isBefore(normalizedStartB) &&
      !normalizedEndB.isBefore(normalizedStartA);
}

DateTime _dateFromEpochMillis(int value) {
  return _dateOnly(DateTime.fromMillisecondsSinceEpoch(value));
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

const Object _sentinel = Object();
