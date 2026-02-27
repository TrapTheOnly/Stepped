import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepped/features/wishlist/gemini_trip_planner.dart';

void main() {
  group('GeminiTripPlanner.mergePlans', () {
    const planner = GeminiTripPlanner();

    test('keeps manual values and appends AI-only cities', () {
      const current = GeminiTripPlan(
        country: 'Spain',
        summary: 'Manual summary',
        stayDuration: GeminiStayDuration(
          days: 9,
          reason: 'Manual duration',
          source: 'user_selected',
        ),
        timeWindows: <GeminiTimeWindow>[
          GeminiTimeWindow(
            label: 'Manual Window',
            months: 'April-May',
            reason: 'Manual reason',
          ),
        ],
        cityPlan: <GeminiCityPlan>[
          GeminiCityPlan(
            city: 'Madrid',
            days: 4,
            reason: 'Manual Madrid reason',
            isExtra: false,
          ),
          GeminiCityPlan(
            city: 'Barcelona',
            days: 3,
            reason: 'Manual Barcelona reason',
            isExtra: false,
          ),
        ],
        cityDetails: <GeminiCityDetail>[
          GeminiCityDetail(
            city: 'Madrid',
            overview: 'Manual overview',
            imageQuery: 'Madrid skyline',
            timeline: <GeminiTimelineStop>[
              GeminiTimelineStop(
                slot: 'Day 1 AM',
                place: 'Plaza Mayor',
                note: 'Manual stop',
              ),
            ],
            thingsToDo: <String>['Manual activity'],
          ),
        ],
        rawText: 'manual',
      );

      const generated = GeminiTripPlan(
        country: 'Spain',
        summary: 'AI summary',
        stayDuration: GeminiStayDuration(
          days: 7,
          reason: 'AI duration',
          source: 'ai_recommended',
        ),
        timeWindows: <GeminiTimeWindow>[
          GeminiTimeWindow(
            label: 'AI Window',
            months: 'June',
            reason: 'AI reason',
          ),
        ],
        cityPlan: <GeminiCityPlan>[
          GeminiCityPlan(
            city: 'Madrid',
            days: 2,
            reason: 'AI Madrid reason',
            isExtra: true,
          ),
          GeminiCityPlan(
            city: 'Valencia',
            days: 2,
            reason: 'AI Valencia reason',
            isExtra: true,
          ),
        ],
        cityDetails: <GeminiCityDetail>[
          GeminiCityDetail(
            city: 'Madrid',
            overview: 'AI overview',
            imageQuery: 'Madrid old town',
            timeline: <GeminiTimelineStop>[
              GeminiTimelineStop(
                slot: 'Day 1 PM',
                place: 'Retiro Park',
                note: 'AI stop',
              ),
            ],
            thingsToDo: <String>['AI activity'],
            image: GeminiCityImage(
              imageUrl: 'https://example.com/madrid.jpg',
              sourcePageUrl: 'https://example.com/page',
              title: 'Madrid',
              creator: 'creator',
              license: 'by-4.0',
              licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
              source: 'openverse',
            ),
          ),
          GeminiCityDetail(
            city: 'Valencia',
            overview: 'Valencia overview',
            imageQuery: 'Valencia skyline',
            timeline: <GeminiTimelineStop>[],
            thingsToDo: <String>['Beach walk'],
          ),
        ],
        rawText: 'generated',
      );

      final merged = planner.mergePlans(current: current, generated: generated);

      expect(merged.summary, 'Manual summary');
      expect(merged.stayDuration?.days, 9);
      expect(merged.timeWindows.first.label, 'Manual Window');
      expect(merged.cityPlan.map((city) => city.city).toList(),
          <String>['Madrid', 'Barcelona', 'Valencia']);
      expect(merged.cityPlan.first.reason, 'Manual Madrid reason');

      final madridDetail = merged.cityDetails
          .firstWhere((detail) => detail.city.toLowerCase() == 'madrid');
      expect(madridDetail.timeline.first.place, 'Plaza Mayor');
      expect(madridDetail.thingsToDo.first, 'Manual activity');
      expect(madridDetail.image?.imageUrl, 'https://example.com/madrid.jpg');
    });

    test('fills blank manual fields from AI output', () {
      const current = GeminiTripPlan(
        country: '',
        summary: '',
        stayDuration: null,
        timeWindows: <GeminiTimeWindow>[],
        cityPlan: <GeminiCityPlan>[
          GeminiCityPlan(
            city: 'Seville',
            days: 0,
            reason: '',
            isExtra: false,
          ),
        ],
        cityDetails: <GeminiCityDetail>[
          GeminiCityDetail(
            city: 'Seville',
            overview: '',
            imageQuery: '',
            timeline: <GeminiTimelineStop>[],
            thingsToDo: <String>[],
          ),
        ],
        rawText: 'manual',
      );

      const generated = GeminiTripPlan(
        country: 'Spain',
        summary: 'AI summary',
        stayDuration: GeminiStayDuration(
          days: 6,
          reason: 'AI duration',
          source: 'ai_recommended',
        ),
        timeWindows: <GeminiTimeWindow>[
          GeminiTimeWindow(
            label: 'Spring',
            months: 'March-April',
            reason: 'Good weather',
          ),
        ],
        cityPlan: <GeminiCityPlan>[
          GeminiCityPlan(
            city: 'Seville',
            days: 3,
            reason: 'Historic center',
            isExtra: false,
          ),
        ],
        cityDetails: <GeminiCityDetail>[
          GeminiCityDetail(
            city: 'Seville',
            overview: 'AI overview',
            imageQuery: 'Seville skyline',
            timeline: <GeminiTimelineStop>[
              GeminiTimelineStop(
                slot: 'Day 1 AM',
                place: 'Alcazar',
                note: 'Start early',
              ),
            ],
            thingsToDo: <String>['Flamenco show'],
          ),
        ],
        rawText: 'generated',
      );

      final merged = planner.mergePlans(current: current, generated: generated);

      expect(merged.country, 'Spain');
      expect(merged.summary, 'AI summary');
      expect(merged.stayDuration?.days, 6);
      expect(merged.timeWindows.single.label, 'Spring');
      expect(merged.cityPlan.single.days, 3);
      expect(merged.cityPlan.single.reason, 'Historic center');

      final sevilleDetail = merged.cityDetails.single;
      expect(sevilleDetail.overview, 'AI overview');
      expect(sevilleDetail.imageQuery, 'Seville skyline');
      expect(sevilleDetail.timeline.single.place, 'Alcazar');
      expect(sevilleDetail.thingsToDo.single, 'Flamenco show');
    });
  });

  group('GeminiTripPlanner storage', () {
    const planner = GeminiTripPlanner();

    test('toStorageJson round-trips via parseStoredPlan', () {
      const plan = GeminiTripPlan(
        country: 'Japan',
        summary: 'Tokyo and Kyoto split.',
        stayDuration: GeminiStayDuration(
          days: 8,
          reason: 'Balanced pace',
          source: 'user_selected',
        ),
        timeWindows: <GeminiTimeWindow>[
          GeminiTimeWindow(
            label: 'Autumn',
            months: 'October-November',
            reason: 'Foliage season',
          ),
        ],
        cityPlan: <GeminiCityPlan>[
          GeminiCityPlan(
            city: 'Tokyo',
            days: 4,
            reason: 'Urban highlights',
            isExtra: false,
          ),
        ],
        cityDetails: <GeminiCityDetail>[
          GeminiCityDetail(
            city: 'Tokyo',
            overview: 'City overview',
            imageQuery: 'Tokyo skyline',
            timeline: <GeminiTimelineStop>[
              GeminiTimelineStop(
                slot: 'Day 1 PM',
                place: 'Shibuya',
                note: 'Crossing at sunset',
              ),
            ],
            thingsToDo: <String>['Sushi tasting'],
          ),
        ],
        rawText: 'raw',
      );

      final encoded = jsonEncode(planner.toStorageJson(plan));
      final parsed = planner.parseStoredPlan(encoded);

      expect(parsed, isNotNull);
      expect(parsed!.country, 'Japan');
      expect(parsed.summary, 'Tokyo and Kyoto split.');
      expect(parsed.stayDuration?.days, 8);
      expect(parsed.cityPlan.single.city, 'Tokyo');
      expect(parsed.cityDetails.single.timeline.single.place, 'Shibuya');
    });
  });
}
