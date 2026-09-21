import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/features/profile/data/models/user_model.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';
import 'package:yolyoldasi/features/ride_requests/data/models/ride_request_model.dart';
import 'package:yolyoldasi/features/ride_requests/domain/entities/ride_request.dart';
import 'package:yolyoldasi/features/rides/data/models/demand_model.dart';
import 'package:yolyoldasi/features/rides/data/models/ride_model.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride_draft.dart';
import 'package:yolyoldasi/features/rides/domain/entities/route_demand.dart';

/// Parsing and rules for the growth features — API.md §19–§22.
///
/// Weighted towards the places where a wrong default is silently wrong rather
/// than loudly broken: an unverified badge on a verified driver, a response
/// rate invented from one data point, a women-only ride that books anyone.
void main() {
  group('RideRequestModel', () {
    // The payload from API.md §19, unchanged.
    final json = {
      'id': 12,
      'passenger': {'id': 7, 'full_name': 'Aysel M.'},
      'from_city': {'id': 1, 'name': 'Bakı'},
      'to_city': {'id': 9, 'name': 'Qəbələ'},
      'wanted_date': '2026-09-25',
      'flexible_days': 1,
      'seats': 2,
      'note': 'Axşam saatları uyğundur.',
      'status': 'open',
      'is_mine': true,
      'matched_ride_id': null,
      'created_at': '2026-09-22T10:00:00+04:00',
    };

    test('parses the documented payload', () {
      final request = RideRequestModel.fromJson(json);

      expect(request.id, 12);
      expect(request.fromCity.name, 'Bakı');
      expect(request.seats, 2);
      expect(request.flexibleDays, 1);
      expect(request.status, RideRequestStatus.open);
      expect(request.isMine, isTrue);
      expect(request.matchedRideId, isNull);
    });

    test('reads `wanted_date` as a local date, not UTC midnight', () {
      // `DateTime.parse('2026-09-25')` is UTC midnight, which is the 24th in
      // any negative offset — the request would silently shift a day.
      final request = RideRequestModel.fromJson(json);

      expect(request.wantedDate.year, 2026);
      expect(request.wantedDate.month, 9);
      expect(request.wantedDate.day, 25);
    });

    test('the flexible window opens both ways', () {
      final request = RideRequestModel.fromJson(json);
      final (from, to) = request.dateRange;

      // ±1 day: a driver going on the 24th or the 26th is still a match.
      expect(from.day, 24);
      expect(to.day, 26);
    });

    test('an unknown status is read as open rather than dropped', () {
      final request = RideRequestModel.fromJson({...json, 'status': 'brand_new'});
      expect(request.status, RideRequestStatus.open);
    });

    test('a past date is expired on the client too', () {
      final past = RideRequestModel.fromJson({
        ...json,
        'wanted_date': '2020-01-01',
        'flexible_days': 0,
      });

      // The server sweeps these nightly; a list left open overnight must not
      // go on offering yesterday in the meantime.
      expect(past.hasExpired, isTrue);
      expect(past.canBeCancelled, isFalse);
    });

    test('the create body sends the date as YYYY-MM-DD', () {
      final body = RideRequestModel.createBody(
        RideRequestDraft(
          fromCityId: 1,
          toCityId: 9,
          wantedDate: DateTime(2026, 9, 5),
          seats: 2,
        ),
      );

      expect(body['wanted_date'], '2026-09-05');
      expect(body.containsKey('note'), isFalse, reason: 'empty note is omitted');
    });

    test('a draft needs two different cities and a date', () {
      const noDate = RideRequestDraft(fromCityId: 1, toCityId: 9);
      expect(noDate.isComplete, isFalse);

      final sameCity = RideRequestDraft(
        fromCityId: 1,
        toCityId: 1,
        wantedDate: DateTime(2026, 9, 5),
      );
      expect(sameCity.isComplete, isFalse);
    });
  });

  group('RideModel — growth fields', () {
    test('parses women_only, is_boosted and share_url', () {
      final ride = RideModel.fromJson({
        'id': 7,
        'from_city': {'id': 1, 'name': 'Bakı'},
        'to_city': {'id': 9, 'name': 'Qəbələ'},
        'departure_at': '2030-09-20T08:00:00+04:00',
        'total_seats': 4,
        'booked_seats': 2,
        'seats_left': 2,
        'price_per_seat': 15.0,
        'status': 'active',
        'created_at': '2026-09-15T09:00:00+04:00',
        'women_only': true,
        'is_boosted': true,
        'share_url': 'https://yolyoldasi.az/r/7',
      });

      expect(ride.womenOnly, isTrue);
      expect(ride.isBoosted, isTrue);
      expect(ride.shareUrl, 'https://yolyoldasi.az/r/7');
    });

    test('an older server that omits them leaves the ride usable', () {
      final ride = RideModel.fromJson({
        'id': 7,
        'from_city': {'id': 1, 'name': 'Bakı'},
        'to_city': {'id': 9, 'name': 'Qəbələ'},
        'departure_at': '2030-09-20T08:00:00+04:00',
        'total_seats': 4,
        'booked_seats': 0,
        'seats_left': 4,
        'price_per_seat': 15.0,
        'status': 'active',
        'created_at': '2026-09-15T09:00:00+04:00',
      });

      expect(ride.womenOnly, isFalse);
      expect(ride.isBoosted, isFalse);
      expect(ride.shareUrl, isNull);
    });

    test('a women-only ride is bookable only by a woman', () {
      final ride = RideModel.fromJson({
        'id': 7,
        'from_city': {'id': 1, 'name': 'Bakı'},
        'to_city': {'id': 9, 'name': 'Qəbələ'},
        'departure_at': '2030-09-20T08:00:00+04:00',
        'total_seats': 4,
        'booked_seats': 0,
        'seats_left': 4,
        'price_per_seat': 15.0,
        'status': 'active',
        'created_at': '2026-09-15T09:00:00+04:00',
        'women_only': true,
      });

      expect(ride.isBookableBy(Gender.female), isTrue);
      expect(ride.isBookableBy(Gender.male), isFalse);
      expect(ride.isBookableBy(Gender.unspecified), isFalse);

      // A signed-out viewer passes the local check and meets the sign-in
      // prompt instead; the server has the final say either way.
      expect(ride.isBookableBy(null), isTrue);
    });

    test('the publish body carries women_only and repeat_weeks', () {
      final body = RideModel.createBody(
        const RideDraftStub(womenOnly: true, repeatWeeks: 4).draft,
      );

      expect(body['women_only'], isTrue);
      expect(body['repeat_weeks'], 4);
    });

    test('repeat_weeks is omitted when it is the default', () {
      final body = RideModel.createBody(const RideDraftStub().draft);
      expect(body.containsKey('repeat_weeks'), isFalse);
    });
  });

  group('UserStatsModel', () {
    test('response stats stay null below the server threshold', () {
      // API.md §21: the server sends null under three requests. A zero
      // fallback would read as "never answers", which is a worse lie than
      // saying nothing.
      final stats = UserStatsModel.fromJson({
        'driver_rating': 4.8,
        'driver_review_count': 12,
        'driver_trip_count': 15,
        'passenger_rating': 5.0,
        'passenger_review_count': 3,
        'passenger_trip_count': 4,
        'driver_response_rate': null,
        'driver_response_minutes': null,
        'driver_tier': 'trusted',
      });

      expect(stats.driverResponseRate, isNull);
      expect(stats.driverResponseMinutes, isNull);
      expect(stats.hasResponseStats, isFalse);
      expect(stats.driverTier, DriverTier.trusted);
      expect(stats.driverTier.isBadgeworthy, isTrue);
    });

    test('an unknown tier degrades to newcomer', () {
      final stats = UserStatsModel.fromJson({'driver_tier': 'platinum'});
      expect(stats.driverTier, DriverTier.newcomer);
      expect(stats.driverTier.isBadgeworthy, isFalse);
    });
  });

  group('PublicUserModel — verification', () {
    test('an absent is_verified is unknown, not false', () {
      final user = PublicUserModel.fromJson({'id': 42, 'full_name': 'Rəşad M.'});

      // The difference matters: rendering unknown as unverified would strip
      // the badge off an approved driver on every screen that does not load
      // the relation (API.md §21).
      expect(user.isVerified, isNull);
      expect(user.showsVerifiedBadge, isFalse);
    });

    test('an explicit false is still no badge', () {
      final user = PublicUserModel.fromJson({
        'id': 42,
        'full_name': 'Rəşad M.',
        'is_verified': false,
      });

      expect(user.isVerified, isFalse);
      expect(user.showsVerifiedBadge, isFalse);
    });

    test('an approved driver gets the badge', () {
      final user = PublicUserModel.fromJson({
        'id': 42,
        'full_name': 'Rəşad M.',
        'is_verified': true,
      });

      expect(user.showsVerifiedBadge, isTrue);
    });
  });

  group('PriceSuggestionModel', () {
    test('a suggestion the server could not make stays null', () {
      final suggestion = PriceSuggestionModel.fromJson({
        'suggested': null,
        'min': null,
        'max': null,
        'source': 'none',
        'sample_size': 0,
        'distance_km': null,
        'fuel_estimate': null,
      });

      // Zero manat would be a price the driver might actually publish.
      expect(suggestion.suggested, isNull);
      expect(suggestion.hasSuggestion, isFalse);
      expect(suggestion.source, PriceSource.none);
    });

    test('parses a history-backed suggestion', () {
      final suggestion = PriceSuggestionModel.fromJson({
        'suggested': 15.0,
        'min': 12.0,
        'max': 18.0,
        'source': 'history',
        'sample_size': 24,
        'distance_km': 225.4,
        'fuel_estimate': 21.6,
      });

      expect(suggestion.source, PriceSource.history);
      expect(suggestion.hasRange, isTrue);
      expect(suggestion.fuelEstimate, 21.6);
    });
  });

  group('RouteDemandModel', () {
    test('a thin route is not worth showing', () {
      final demand = RouteDemandModel.fromJson({
        'searches': 2,
        'requests': 0,
        'requested_seats': 0,
        'active_rides': 0,
        'seats_available': 0,
        'window_days': 7,
      });

      // "2 people searched" reads as "nobody wants this" and talks a driver
      // out of a route rather than into one.
      expect(demand.isWorthShowing, isFalse);
    });

    test('a single concrete request is enough', () {
      final demand = RouteDemandModel.fromJson({
        'searches': 1,
        'requests': 1,
        'requested_seats': 2,
        'active_rides': 0,
        'seats_available': 0,
        'window_days': 7,
      });

      expect(demand.isWorthShowing, isTrue);
      expect(demand.isUnderserved, isTrue);
    });
  });
}

/// A complete [RideDraft] with the two growth fields overridable.
///
/// Wrapped rather than built inline because `createBody` asserts on a complete
/// draft, and every test here cares about exactly two of its ten fields.
class RideDraftStub {
  const RideDraftStub({this.womenOnly = false, this.repeatWeeks = 1});

  final bool womenOnly;
  final int repeatWeeks;

  RideDraft get draft => RideDraft(
    vehicleId: 3,
    fromCityId: 1,
    toCityId: 9,
    date: DateTime(2030, 9, 20),
    timeOfDayMinutes: 8 * 60,
    totalSeats: 3,
    pricePerSeat: 15,
    womenOnly: womenOnly,
    repeatWeeks: repeatWeeks,
  );
}
