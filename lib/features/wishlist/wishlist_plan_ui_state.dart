import 'dart:convert';

const _uiStateKey = 'ui_state';
const _cityThingChecksKey = 'city_thing_checks';
const _coverImageKey = 'cover_image';
const _coverImageQueryKey = 'cover_image_query';
const _requestKey = 'request';

Map<String, dynamic> mergeWishlistPlanUiState({
  required Map<String, dynamic> payload,
  required String? existingRawPlan,
}) {
  final existing = _decodePlanMap(existingRawPlan);
  if (existing == null) {
    return payload;
  }

  final rawUiState = existing[_uiStateKey];
  if (rawUiState is! Map) {
    return _mergeStoredPlanMetadata(payload, existing);
  }

  final uiState = _asStringKeyedMap(rawUiState);
  if (uiState.isEmpty) {
    return _mergeStoredPlanMetadata(payload, existing);
  }

  return _mergeStoredPlanMetadata(
    <String, dynamic>{
      ...payload,
      _uiStateKey: uiState,
    },
    existing,
  );
}

Map<String, dynamic> _mergeStoredPlanMetadata(
  Map<String, dynamic> payload,
  Map<String, dynamic> existing,
) {
  final merged = <String, dynamic>{...payload};
  final rawCoverImage = existing[_coverImageKey];
  if (!merged.containsKey(_coverImageKey) && rawCoverImage is Map) {
    merged[_coverImageKey] = _asStringKeyedMap(rawCoverImage);
  }
  final rawCoverImageQuery = existing[_coverImageQueryKey];
  if (!merged.containsKey(_coverImageQueryKey) &&
      rawCoverImageQuery is String &&
      rawCoverImageQuery.trim().isNotEmpty) {
    merged[_coverImageQueryKey] = rawCoverImageQuery.trim();
  }
  final rawRequest = existing[_requestKey];
  if (!merged.containsKey(_requestKey) && rawRequest is Map) {
    merged[_requestKey] = _asStringKeyedMap(rawRequest);
  }
  return merged;
}

Set<String> readWishlistCompletedThingKeys({
  required String? rawPlan,
  required String cityName,
}) {
  final cityChecks = _readCityThingChecks(
    rawPlan: rawPlan,
    cityName: cityName,
  );
  if (cityChecks.isEmpty) {
    return const <String>{};
  }

  final completed = <String>{};
  for (final entry in cityChecks.entries) {
    if (_readBool(entry.value) ?? false) {
      completed.add(entry.key);
    }
  }
  return completed;
}

String? writeWishlistThingCompletionState({
  required String? rawPlan,
  required String cityName,
  required String thingLabel,
  required bool completed,
}) {
  final planMap = _decodePlanMap(rawPlan);
  if (planMap == null) {
    return rawPlan;
  }

  final uiState = _ensureMap(planMap, _uiStateKey);
  final cityThingChecks = _ensureMap(uiState, _cityThingChecksKey);
  final cityChecks = _ensureMap(
    cityThingChecks,
    normalizeWishlistPlanCityKey(cityName),
  );
  final thingKey = normalizeWishlistPlanThingKey(thingLabel);

  if (completed) {
    cityChecks[thingKey] = true;
  } else {
    cityChecks.remove(thingKey);
  }

  if (cityChecks.isEmpty) {
    cityThingChecks.remove(normalizeWishlistPlanCityKey(cityName));
  }
  if (cityThingChecks.isEmpty) {
    uiState.remove(_cityThingChecksKey);
  }
  if (uiState.isEmpty) {
    planMap.remove(_uiStateKey);
  }

  return jsonEncode(planMap);
}

String normalizeWishlistPlanCityKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeWishlistPlanThingKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

Map<String, dynamic> _readCityThingChecks({
  required String? rawPlan,
  required String cityName,
}) {
  final planMap = _decodePlanMap(rawPlan);
  if (planMap == null) {
    return const <String, dynamic>{};
  }

  final rawUiState = planMap[_uiStateKey];
  if (rawUiState is! Map) {
    return const <String, dynamic>{};
  }
  final rawCityThingChecks = rawUiState[_cityThingChecksKey];
  if (rawCityThingChecks is! Map) {
    return const <String, dynamic>{};
  }
  final rawCityChecks =
      rawCityThingChecks[normalizeWishlistPlanCityKey(cityName)];
  if (rawCityChecks is! Map) {
    return const <String, dynamic>{};
  }
  return _asStringKeyedMap(rawCityChecks);
}

Map<String, dynamic>? _decodePlanMap(String? rawPlan) {
  if (rawPlan == null || rawPlan.trim().isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(rawPlan);
    if (decoded is! Map) {
      return null;
    }
    return _asStringKeyedMap(decoded);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _ensureMap(
  Map<String, dynamic> source,
  String key,
) {
  final existing = source[key];
  if (existing is Map) {
    final converted = _asStringKeyedMap(existing);
    source[key] = converted;
    return converted;
  }
  final created = <String, dynamic>{};
  source[key] = created;
  return created;
}

Map<String, dynamic> _asStringKeyedMap(Map source) {
  final converted = <String, dynamic>{};
  for (final entry in source.entries) {
    final key = entry.key?.toString();
    if (key == null || key.trim().isEmpty) {
      continue;
    }
    final value = entry.value;
    if (value is Map) {
      converted[key] = _asStringKeyedMap(value);
    } else if (value is List) {
      converted[key] = value
          .map((item) => item is Map ? _asStringKeyedMap(item) : item)
          .toList(growable: false);
    } else {
      converted[key] = value;
    }
  }
  return converted;
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
