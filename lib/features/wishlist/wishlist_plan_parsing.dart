import 'dart:convert';

import 'package:flutter/material.dart';

import 'gemini_trip_planner.dart';
import 'wishlist_plan_form_types.dart';

class WishlistStoredRequestOptions {
  const WishlistStoredRequestOptions({
    required this.timeInputMode,
    required this.selectedMonth,
    required this.selectedDurationPreference,
    required this.allowAdditionalCities,
    required this.purpose,
  });

  final WishlistTimeInputMode timeInputMode;
  final int? selectedMonth;
  final GeminiDurationPreference? selectedDurationPreference;
  final bool? allowAdditionalCities;
  final String? purpose;
}

WishlistStoredRequestOptions? parseWishlistStoredRequestOptions(
    String rawPlan) {
  final raw = rawPlan.trim();
  if (raw.isEmpty) {
    return null;
  }

  final decoded = _tryDecodeJson(raw);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final request = decoded['request'];
  if (request is! Map<String, dynamic>) {
    return null;
  }

  var mode = WishlistTimeInputMode.aiRecommended;
  final modeRaw = (request['time_mode'] as String?)?.trim();
  switch (modeRaw) {
    case 'precise_dates':
      mode = WishlistTimeInputMode.preciseDates;
    case 'month_and_duration':
      mode = WishlistTimeInputMode.monthAndDuration;
    case 'ai_recommended':
      mode = WishlistTimeInputMode.aiRecommended;
  }

  int? selectedMonth;
  final month = _readInt(request['preferred_month']);
  if (month != null && month >= 1 && month <= DateTime.december) {
    selectedMonth = month;
  }

  GeminiDurationPreference? selectedDurationPreference;
  final durationId = (request['duration_preference_id'] as String?)?.trim();
  if (durationId != null && durationId.isNotEmpty) {
    for (final option in geminiDurationPreferences) {
      if (option.id == durationId) {
        selectedDurationPreference = option;
        break;
      }
    }
  }

  return WishlistStoredRequestOptions(
    timeInputMode: mode,
    selectedMonth: selectedMonth,
    selectedDurationPreference: selectedDurationPreference,
    allowAdditionalCities: _readBool(request['allow_extra_cities']),
    purpose: _readString(request['purpose']),
  );
}

Map<String, dynamic> buildWishlistRequestPayload({
  required WishlistTimeInputMode timeInputMode,
  required bool allowAdditionalCities,
  required String? purpose,
  required int? selectedMonth,
  required GeminiDurationPreference? selectedDurationPreference,
  required DateTimeRange? dateRange,
}) {
  final payload = <String, dynamic>{
    'time_mode': switch (timeInputMode) {
      WishlistTimeInputMode.aiRecommended => 'ai_recommended',
      WishlistTimeInputMode.preciseDates => 'precise_dates',
      WishlistTimeInputMode.monthAndDuration => 'month_and_duration',
    },
    'allow_extra_cities': allowAdditionalCities,
    if (purpose != null && purpose.trim().isNotEmpty) 'purpose': purpose.trim(),
  };

  if (timeInputMode == WishlistTimeInputMode.monthAndDuration) {
    if (selectedMonth != null) {
      payload['preferred_month'] = selectedMonth;
    }
    if (selectedDurationPreference != null) {
      payload['duration_preference_id'] = selectedDurationPreference.id;
    }
  }

  if (timeInputMode == WishlistTimeInputMode.preciseDates &&
      dateRange != null) {
    payload['precise_start'] = dateRange.start.millisecondsSinceEpoch;
    payload['precise_end'] = dateRange.end.millisecondsSinceEpoch;
  }

  return payload;
}

dynamic _tryDecodeJson(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

bool? _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is! String) {
    return null;
  }
  final normalized = value.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return null;
}

String? _readString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}
