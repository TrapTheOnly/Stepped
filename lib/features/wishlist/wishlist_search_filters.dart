import '../../data/db/app_db_models.dart';

enum WishlistListStatusFilter {
  any('Any'),
  upcoming('Upcoming'),
  ongoing('Ongoing'),
  past('Past'),
  unscheduled('No dates');

  const WishlistListStatusFilter(this.label);
  final String label;
}

class WishlistSearchFilters {
  const WishlistSearchFilters({
    this.query = '',
    this.status = WishlistListStatusFilter.any,
    this.country,
    this.year,
    this.dateRange,
  });

  final String query;
  final WishlistListStatusFilter status;
  final String? country;
  final int? year;
  final DateTimeRangeValue? dateRange;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      status != WishlistListStatusFilter.any ||
      country != null ||
      year != null ||
      dateRange != null;

  WishlistSearchFilters copyWith({
    String? query,
    WishlistListStatusFilter? status,
    Object? country = _sentinel,
    Object? year = _sentinel,
    Object? dateRange = _sentinel,
  }) {
    return WishlistSearchFilters(
      query: query ?? this.query,
      status: status ?? this.status,
      country:
          identical(country, _sentinel) ? this.country : country as String?,
      year: identical(year, _sentinel) ? this.year : year as int?,
      dateRange: identical(dateRange, _sentinel)
          ? this.dateRange
          : dateRange as DateTimeRangeValue?,
    );
  }

  WishlistSearchFilters cleared({String? query}) {
    return WishlistSearchFilters(query: query ?? this.query);
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

List<WishlistItemRecord> applyWishlistSearchFilters(
  List<WishlistItemRecord> items,
  WishlistSearchFilters filters, {
  DateTime? now,
}) {
  final effectiveNow = _dateOnly(now ?? DateTime.now());
  final normalizedQuery = filters.query.trim().toLowerCase();

  return items.where((item) {
    if (normalizedQuery.isNotEmpty) {
      final haystack = <String>[
        item.title,
        item.countryName ?? '',
        item.countryCode ?? '',
        item.plannedCities ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(normalizedQuery)) {
        return false;
      }
    }

    if (filters.country != null && item.countryName != filters.country) {
      return false;
    }

    final start = item.plannedStartDate == null
        ? null
        : _dateFromEpochMillis(item.plannedStartDate!);
    final end = item.plannedEndDate == null
        ? null
        : _dateFromEpochMillis(item.plannedEndDate!);

    if (filters.status != WishlistListStatusFilter.any &&
        wishlistListStatusForRecord(item, now: effectiveNow) !=
            filters.status) {
      return false;
    }

    if (filters.year != null) {
      if (start == null || end == null) {
        return false;
      }
      if (!_rangeTouchesYear(start: start, end: end, year: filters.year!)) {
        return false;
      }
    }

    if (filters.dateRange != null) {
      if (start == null || end == null) {
        return false;
      }
      if (!_rangesOverlap(
        start,
        end,
        filters.dateRange!.start,
        filters.dateRange!.end,
      )) {
        return false;
      }
    }

    return true;
  }).toList(growable: false);
}

List<String> wishlistCountryFilterOptions(List<WishlistItemRecord> items) {
  final countries = items
      .map((item) => item.countryName?.trim() ?? '')
      .where((country) => country.isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
  return countries;
}

List<int> wishlistYearFilterOptions(List<WishlistItemRecord> items) {
  final years = <int>{};
  for (final item in items) {
    if (item.plannedStartDate == null || item.plannedEndDate == null) {
      continue;
    }
    final start = _dateFromEpochMillis(item.plannedStartDate!);
    final end = _dateFromEpochMillis(item.plannedEndDate!);
    for (var year = start.year; year <= end.year; year++) {
      years.add(year);
    }
  }
  return years.toList(growable: false)..sort((a, b) => b.compareTo(a));
}

WishlistListStatusFilter wishlistListStatusForRecord(
  WishlistItemRecord item, {
  DateTime? now,
}) {
  if (item.plannedStartDate == null || item.plannedEndDate == null) {
    return WishlistListStatusFilter.unscheduled;
  }
  return _wishlistStatusFor(
    start: _dateFromEpochMillis(item.plannedStartDate!),
    end: _dateFromEpochMillis(item.plannedEndDate!),
    now: _dateOnly(now ?? DateTime.now()),
  );
}

WishlistListStatusFilter _wishlistStatusFor({
  required DateTime start,
  required DateTime end,
  required DateTime now,
}) {
  if (end.isBefore(now)) {
    return WishlistListStatusFilter.past;
  }
  if (start.isAfter(now)) {
    return WishlistListStatusFilter.upcoming;
  }
  return WishlistListStatusFilter.ongoing;
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
