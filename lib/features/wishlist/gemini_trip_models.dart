class GeminiPlannerException implements Exception {
  const GeminiPlannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiDurationPreference {
  const GeminiDurationPreference({
    required this.id,
    required this.label,
    required this.minDays,
    required this.maxDays,
    required this.description,
  });

  final String id;
  final String label;
  final int minDays;
  final int maxDays;
  final String description;
}

const List<GeminiDurationPreference> geminiDurationPreferences =
    <GeminiDurationPreference>[
  GeminiDurationPreference(
    id: 'quick_escape',
    label: 'Quick Escape',
    minDays: 3,
    maxDays: 5,
    description: 'Short, high-energy city break.',
  ),
  GeminiDurationPreference(
    id: 'balanced_week',
    label: 'Balanced Week',
    minDays: 6,
    maxDays: 8,
    description: 'Comfortable pace with top highlights.',
  ),
  GeminiDurationPreference(
    id: 'deep_dive',
    label: 'Deep Dive',
    minDays: 9,
    maxDays: 12,
    description: 'More neighborhoods and city depth.',
  ),
  GeminiDurationPreference(
    id: 'grand_journey',
    label: 'Grand Journey',
    minDays: 13,
    maxDays: 18,
    description: 'Slower pace and broader coverage.',
  ),
];

class GeminiTimeWindow {
  const GeminiTimeWindow({
    required this.label,
    required this.months,
    required this.reason,
  });

  final String label;
  final String months;
  final String reason;
}

class GeminiStayDuration {
  const GeminiStayDuration({
    required this.days,
    required this.reason,
    required this.source,
  });

  final int days;
  final String reason;
  final String source;
}

class GeminiRecommendedDates {
  const GeminiRecommendedDates({
    required this.start,
    required this.end,
    required this.reason,
  });

  final DateTime start;
  final DateTime end;
  final String reason;
}

class GeminiCityPlan {
  const GeminiCityPlan({
    required this.city,
    required this.days,
    required this.reason,
    required this.isExtra,
  });

  final String city;
  final int days;
  final String reason;
  final bool isExtra;
}

class GeminiTimelineStop {
  const GeminiTimelineStop({
    required this.slot,
    required this.place,
    required this.note,
  });

  final String slot;
  final String place;
  final String note;
}

class GeminiCityImage {
  const GeminiCityImage({
    required this.imageUrl,
    required this.sourcePageUrl,
    required this.title,
    required this.creator,
    required this.license,
    required this.licenseUrl,
    required this.source,
  });

  final String imageUrl;
  final String sourcePageUrl;
  final String title;
  final String creator;
  final String license;
  final String licenseUrl;
  final String source;
}

class GeminiCityDetail {
  const GeminiCityDetail({
    required this.city,
    required this.overview,
    required this.imageQuery,
    required this.timeline,
    required this.thingsToDo,
    this.image,
  });

  final String city;
  final String overview;
  final String imageQuery;
  final List<GeminiTimelineStop> timeline;
  final List<String> thingsToDo;
  final GeminiCityImage? image;

  GeminiCityDetail copyWith({
    GeminiCityImage? image,
  }) {
    return GeminiCityDetail(
      city: city,
      overview: overview,
      imageQuery: imageQuery,
      timeline: timeline,
      thingsToDo: thingsToDo,
      image: image ?? this.image,
    );
  }
}

class GeminiTripPlan {
  const GeminiTripPlan({
    required this.country,
    required this.summary,
    required this.stayDuration,
    required this.recommendedDates,
    required this.timeWindows,
    required this.cityPlan,
    required this.cityDetails,
    required this.rawText,
  });

  final String country;
  final String summary;
  final GeminiStayDuration? stayDuration;
  final GeminiRecommendedDates? recommendedDates;
  final List<GeminiTimeWindow> timeWindows;
  final List<GeminiCityPlan> cityPlan;
  final List<GeminiCityDetail> cityDetails;
  final String rawText;
}
