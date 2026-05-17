import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';

class TripUi {
  const TripUi({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.dateRange,
    required this.cities,
    this.coverImageUri,
    this.notes,
  });

  final int id;
  final String countryCode;
  final String countryName;
  final String dateRange;
  final String cities;
  final String? coverImageUri;
  final String? notes;

  factory TripUi.fromRecord(TripRecord trip) {
    final tripId = trip.id;
    if (tripId == null) {
      throw ArgumentError('TripUi requires a persisted TripRecord with id.');
    }

    return TripUi(
      id: tripId,
      countryCode: trip.countryCode,
      countryName: trip.countryName,
      dateRange: _formatDateRange(trip.startDate, trip.endDate),
      cities: trip.cities,
      coverImageUri: trip.coverImageUri,
      notes: trip.notes,
    );
  }

  static String _formatDateRange(int start, int end) {
    final startDate = DateTime.fromMillisecondsSinceEpoch(start);
    final endDate = DateTime.fromMillisecondsSinceEpoch(end);

    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d, y');

    return '${startFormat.format(startDate)} - ${endFormat.format(endDate)}';
  }
}
