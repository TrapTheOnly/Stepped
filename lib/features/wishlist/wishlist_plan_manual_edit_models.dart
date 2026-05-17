import 'gemini_trip_planner.dart';

class EditableTimeWindow {
  const EditableTimeWindow({
    required this.id,
    required this.label,
    required this.months,
    required this.reason,
  });

  final int id;
  final String label;
  final String months;
  final String reason;

  EditableTimeWindow copyWith({
    int? id,
    String? label,
    String? months,
    String? reason,
  }) {
    return EditableTimeWindow(
      id: id ?? this.id,
      label: label ?? this.label,
      months: months ?? this.months,
      reason: reason ?? this.reason,
    );
  }
}

class EditableCity {
  EditableCity({
    required this.id,
    required this.originalCityKey,
    required this.originalImageQuery,
    required this.city,
    required this.days,
    required this.reason,
    required this.isExtra,
    required this.overview,
    required this.imageQuery,
    required this.timeline,
    required this.thingsToDo,
    this.image,
  });

  final int id;
  final String? originalCityKey;
  final String originalImageQuery;
  String city;
  int days;
  String reason;
  bool isExtra;
  String overview;
  String imageQuery;
  List<EditableTimeline> timeline;
  List<EditableThing> thingsToDo;
  GeminiCityImage? image;
}

class EditableTimeline {
  const EditableTimeline({
    required this.id,
    required this.slot,
    required this.place,
    required this.note,
  });

  final int id;
  final String slot;
  final String place;
  final String note;

  EditableTimeline copyWith({
    int? id,
    String? slot,
    String? place,
    String? note,
  }) {
    return EditableTimeline(
      id: id ?? this.id,
      slot: slot ?? this.slot,
      place: place ?? this.place,
      note: note ?? this.note,
    );
  }
}

class EditableThing {
  const EditableThing({
    required this.id,
    required this.value,
  });

  final int id;
  final String value;

  EditableThing copyWith({
    int? id,
    String? value,
  }) {
    return EditableThing(
      id: id ?? this.id,
      value: value ?? this.value,
    );
  }
}

class WishlistManualHydratedState {
  const WishlistManualHydratedState({
    required this.country,
    required this.summary,
    required this.durationDays,
    required this.durationReason,
    required this.durationSource,
    required this.coverImage,
    required this.timeWindows,
    required this.cities,
    required this.requestPayload,
  });

  final String country;
  final String summary;
  final String durationDays;
  final String durationReason;
  final String durationSource;
  final GeminiCityImage? coverImage;
  final List<EditableTimeWindow> timeWindows;
  final List<EditableCity> cities;
  final Map<String, dynamic>? requestPayload;
}

String manualCityKey(String value) => value.trim().toLowerCase();

GeminiCityImage buildManualWishlistImage(
  String uri, {
  String title = 'Manual image',
}) {
  return GeminiCityImage(
    imageUrl: uri.trim(),
    sourcePageUrl: '',
    title: title,
    creator: 'You',
    license: 'private',
    licenseUrl: '',
    source: 'manual',
  );
}
