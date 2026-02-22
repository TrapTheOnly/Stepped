import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_db.dart';
import '../repositories/trips_repository.dart';
import '../repositories/wishlist_repository.dart';

const _seedFlagKey = 'stepped_seed_v1';

final appStartupProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final seeder = SeedDataService(
    preferences: prefs,
    tripsRepository: ref.read(tripsRepositoryProvider),
    wishlistRepository: ref.read(wishlistRepositoryProvider),
  );
  await seeder.ensureSeeded();
});

class SeedDataService {
  const SeedDataService({
    required this.preferences,
    required this.tripsRepository,
    required this.wishlistRepository,
  });

  final SharedPreferences preferences;
  final TripsRepository tripsRepository;
  final WishlistRepository wishlistRepository;

  Future<void> ensureSeeded() async {
    final alreadySeeded = preferences.getBool(_seedFlagKey) ?? false;
    if (alreadySeeded) {
      return;
    }

    final trips = <TripRecord>[
      TripRecord(
        countryCode: 'JP',
        countryName: 'Japan',
        startDate: DateTime(2024, 4, 12).millisecondsSinceEpoch,
        endDate: DateTime(2024, 4, 22).millisecondsSinceEpoch,
        cities: 'Tokyo, Kyoto, Osaka',
        coverImageUri:
            'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800',
        notes: 'Spring trip during cherry blossom season.',
      ),
      TripRecord(
        countryCode: 'IT',
        countryName: 'Italy',
        startDate: DateTime(2023, 9, 3).millisecondsSinceEpoch,
        endDate: DateTime(2023, 9, 14).millisecondsSinceEpoch,
        cities: 'Rome, Florence, Venice',
        coverImageUri:
            'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?w=800',
        notes: 'Historic route through central Italy.',
      ),
      TripRecord(
        countryCode: 'TR',
        countryName: 'Turkey',
        startDate: DateTime(2023, 5, 5).millisecondsSinceEpoch,
        endDate: DateTime(2023, 5, 12).millisecondsSinceEpoch,
        cities: 'Istanbul, Cappadocia',
        coverImageUri:
            'https://images.unsplash.com/photo-1541432901042-2d8bd64b4a9b?w=800',
        notes: 'City and landscape mix.',
      ),
      TripRecord(
        countryCode: 'AE',
        countryName: 'United Arab Emirates',
        startDate: DateTime(2022, 11, 18).millisecondsSinceEpoch,
        endDate: DateTime(2022, 11, 23).millisecondsSinceEpoch,
        cities: 'Dubai, Abu Dhabi',
        coverImageUri:
            'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800',
        notes: 'Short winter getaway.',
      ),
    ];

    for (final trip in trips) {
      await tripsRepository.addTrip(trip);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await wishlistRepository.addWishlistItem(
      WishlistItemRecord(
        title: 'See Northern Lights',
        countryName: 'Norway',
        createdAt: now,
      ),
    );
    await wishlistRepository.addWishlistItem(
      WishlistItemRecord(
        title: 'Safari Adventure',
        countryName: 'Kenya',
        createdAt: now - const Duration(days: 1).inMilliseconds,
      ),
    );

    await preferences.setBool(_seedFlagKey, true);
  }
}

