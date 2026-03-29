import 'gemini_trip_models.dart';

Map<String, dynamic> geminiPlanToStorageJson(GeminiTripPlan plan) {
  return <String, dynamic>{
    'country': plan.country,
    'summary': plan.summary,
    'duration': plan.stayDuration == null
        ? null
        : <String, dynamic>{
            'days': plan.stayDuration!.days,
            'reason': plan.stayDuration!.reason,
            'source': plan.stayDuration!.source,
          },
    'recommended_dates': plan.recommendedDates == null
        ? null
        : <String, dynamic>{
            'start': _toIsoDate(plan.recommendedDates!.start),
            'end': _toIsoDate(plan.recommendedDates!.end),
            'reason': plan.recommendedDates!.reason,
          },
    'time_windows': <Map<String, dynamic>>[
      for (final window in plan.timeWindows)
        <String, dynamic>{
          'label': window.label,
          'months': window.months,
          'reason': window.reason,
        },
    ],
    'city_plan': <Map<String, dynamic>>[
      for (final city in plan.cityPlan)
        <String, dynamic>{
          'city': city.city,
          'days': city.days,
          'reason': city.reason,
          'is_extra': city.isExtra,
        },
    ],
    'city_cards': <Map<String, dynamic>>[
      for (final card in plan.cityDetails)
        <String, dynamic>{
          'city': card.city,
          'overview': card.overview,
          'image_query': card.imageQuery,
          'timeline': <Map<String, dynamic>>[
            for (final stop in card.timeline)
              <String, dynamic>{
                'slot': stop.slot,
                'place': stop.place,
                'note': stop.note,
              },
          ],
          'things_to_do': <String>[
            for (final item in card.thingsToDo) item,
          ],
          'image': card.image == null
              ? null
              : <String, dynamic>{
                  'image_url': card.image!.imageUrl,
                  'source_page_url': card.image!.sourcePageUrl,
                  'title': card.image!.title,
                  'creator': card.image!.creator,
                  'license': card.image!.license,
                  'license_url': card.image!.licenseUrl,
                  'source': card.image!.source,
                },
        },
    ],
  };
}

String _toIsoDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
