import 'package:flutter/material.dart';

Future<DateTimeRange?> pickWishlistDateRange({
  required BuildContext context,
  required DateTimeRange? currentRange,
}) async {
  final now = DateTime.now();
  final initialRange = currentRange ??
      DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 6)),
      );
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 5),
    initialDateRange: initialRange,
  );
}

String formatWishlistDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
