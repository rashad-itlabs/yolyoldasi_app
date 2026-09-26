import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/network/api_envelope.dart';
import 'package:yolyoldasi/features/bookings/data/models/booking_model.dart';
import 'package:yolyoldasi/features/bookings/domain/entities/booking.dart';
import 'package:yolyoldasi/features/chat/data/models/chat_model.dart';
import 'package:yolyoldasi/features/notifications/data/models/notification_model.dart';
import 'package:yolyoldasi/features/notifications/domain/entities/app_notification.dart';
import 'package:yolyoldasi/features/profile/data/models/driver_profile_model.dart';
import 'package:yolyoldasi/features/profile/data/models/user_model.dart';
import 'package:yolyoldasi/features/profile/data/models/vehicle_model.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';
import 'package:yolyoldasi/features/reviews/data/models/review_model.dart';
import 'package:yolyoldasi/features/rides/data/models/ride_model.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride_draft.dart';

/// Parsing tests built from the exact payloads in `API.md`.
///
/// The section that matters most is §16.5: a dozen keys are *absent* rather
/// than null, and every one of them has taken a screen down at some point in a
/// project like this.
void main() {
  group('Envelope', () {
    test('unwraps a `data` object', () {
      expect(
        Envelope.object({
          'data': {'id': 1},
        }),
        {'id': 1},
      );
    });

    test('falls through to the body when there is no envelope', () {
      // `/auth/firebase` and the unread-count endpoints answer bare.
      expect(Envelope.object({'unread_total': 5}), {'unread_total': 5});
    });

    test('reads a `data` list', () {
      expect(
        Envelope.list({
          'data': [
            {'id': 1},
            {'id': 2},
          ],
        }),
        hasLength(2),
      );
    });
  });

  group('Paginated', () {
    const body = {
      'data': [
        {'id': 1},
        {'id': 2},
      ],
      'meta': {'current_page': 1, 'last_page': 4, 'per_page': 20, 'total': 74},
    };

    test('carries the cursor from meta', () {
      final page = Paginated.fromBody(body, (json) => json['id'] as int);
      expect(page.items, [1, 2]);
      expect(page.hasMore, isTrue);
      expect(page.nextPage, 2);
      expect(page.meta.total, 74);
    });

    test('treats a missing meta as a single full page', () {
      final page = Paginated.fromBody({
        'data': [
          {'id': 1},
        ],
      }, (json) => json['id'] as int);
      expect(page.hasMore, isFalse);
    });

    test('concat keeps the newer cursor', () {
      final first = Paginated.fromBody(body, (json) => json['id'] as int);
      final second = Paginated.fromBody({
        'data': [
          {'id': 3},
        ],
        'meta': {
          'current_page': 4,
          'last_page': 4,
          'per_page': 20,
          'total': 74,
        },
      }, (json) => json['id'] as int);

      final merged = first.concat(second);
      expect(merged.items, [1, 2, 3]);
      expect(merged.hasMore, isFalse);
    });
  });

  group('UserModel', () {
    test('parses the /me payload from API.md §4', () {
      final user = UserModel.fromJson({
        'id': 42,
        'phone': '+994501234567',
        'phone_verified_at': '2026-09-15T12:00:00+04:00',
        'full_name': 'Rəşad Məmmədov',
        'photo_url': 'https://example.test/x.jpg',
        'about': 'Həftə sonu Bakı–Qəbələ gedirəm.',
        'gender': 'male',
        'birth_year': 1994,
        'city': {'id': 1, 'name': 'Bakı'},
        'active_mode': 'passenger',
        'has_driver_profile': true,
        'language_code': 'az',
        'is_admin': false,
        'stats': {
          'driver_rating': 4.8,
          'driver_review_count': 12,
          'driver_trip_count': 15,
          'passenger_rating': 5.0,
          'passenger_review_count': 3,
          'passenger_trip_count': 4,
        },
        'notification_preferences': {
          'push_enabled': true,
          'bookings': true,
          'messages': true,
          'reminders': true,
          'marketing': false,
        },
      });

      expect(user.id, 42);
      expect(user.gender, Gender.male);
      expect(user.activeMode, UserMode.passenger);
      expect(user.city?.name, 'Bakı');
      expect(user.stats.driverRating, 4.8);
      expect(user.isProfileComplete, isTrue);
      expect(user.notificationPreferences.marketing, isFalse);
    });

    test('survives a payload with every optional key absent', () {
      // API.md §16.5: `city`, `photo_url`, `about` and `birth_year` may simply
      // not be there.
      final user = UserModel.fromJson({'id': 7, 'phone': '+994500000000'});

      expect(user.city, isNull);
      expect(user.photoUrl, isNull);
      expect(user.birthYear, isNull);
      expect(user.about, isEmpty);
      expect(user.isProfileComplete, isFalse);
    });

    test('patchBody omits untouched fields and keeps explicit nulls', () {
      final body = UserModel.patchBody(
        fullName: 'Aysel',
        // Clearing the city has to reach the wire as `city_id: null`, which is
        // how `PATCH /me` tells it apart from "leave it alone".
        cityId: () => null,
      );

      expect(body.containsKey('full_name'), isTrue);
      expect(body.containsKey('city_id'), isTrue);
      expect(body['city_id'], isNull);
      expect(body.containsKey('about'), isFalse);
      expect(body.containsKey('gender'), isFalse);
    });
  });

  group('RideModel', () {
    final json = {
      'id': 7,
      'driver': {
        'id': 42,
        'full_name': 'Rəşad M.',
        'photo_url': null,
        'gender': 'male',
        'birth_year': 1994,
        'has_driver_profile': true,
        'stats': {'driver_rating': 4.8, 'driver_review_count': 12},
      },
      'vehicle': {
        'id': 3,
        'brand': 'Toyota',
        'model': 'Prius',
        'color': 'Ağ',
        'year': 2018,
        'seats': 4,
      },
      'from_city': {'id': 1, 'name': 'Bakı'},
      'to_city': {'id': 9, 'name': 'Qəbələ'},
      'departure_at': '2026-09-20T08:00:00+04:00',
      'total_seats': 4,
      'booked_seats': 2,
      'seats_left': 2,
      'price_per_seat': 15.0,
      'status': 'active',
      'note': 'Siqaret çəkilmir.',
      'pickup_point': '20 Yanvar metrosu',
      'dropoff_point': 'Qəbələ mərkəz',
      'instant_booking': false,
      'is_mine': false,
      'created_at': '2026-09-15T09:00:00+04:00',
    };

    test('parses the ride object from API.md §9', () {
      final ride = RideModel.fromJson(json);

      expect(ride.id, 7);
      expect(ride.status, RideStatus.active);
      expect(ride.fromCity.name, 'Bakı');
      expect(ride.seatsLeft, 2);
      expect(ride.pricePerSeat, 15.0);
      expect(ride.isMine, isFalse);
      expect(ride.totalPriceFor(2), 30.0);
    });

    test('leaves the plate null when the API withheld it', () {
      // §9: `vehicle.plate` is returned only to the driver themselves, so on
      // somebody else's ride the key is not in the response at all.
      final ride = RideModel.fromJson(json);
      expect(ride.vehicle?.plate, isNull);
      expect(ride.visiblePlate, isNull);
    });

    test('prefers the server seats_left over recomputing it', () {
      // §16.3 is explicit about this. A deliberately inconsistent payload
      // proves the client is not doing the subtraction itself.
      final ride = RideModel.fromJson({...json, 'seats_left': 1});
      expect(ride.seatsLeft, 1);
    });

    test('updateBody leaves out the fields an edit may not touch', () {
      final ride = RideModel.fromJson(json);
      // Seeding the draft from the ride is exactly what the edit form does.
      final body = RideModel.updateBody(RideDraft.fromRide(ride));

      // §9 lists what PUT accepts; the route and the car are not on it.
      expect(body.containsKey('from_city_id'), isFalse);
      expect(body.containsKey('to_city_id'), isFalse);
      expect(body.containsKey('vehicle_id'), isFalse);
      expect(body['total_seats'], 4);
    });
  });

  group('VehicleModel', () {
    test('round-trips an optional-field-free car', () {
      final vehicle = VehicleModel.fromJson({
        'id': 3,
        'brand': 'Toyota',
        'model': 'Prius',
      });

      expect(vehicle.color, isNull);
      expect(vehicle.plate, isNull);
      expect(vehicle.year, isNull);
      // API.md §8: `seats` defaults to 4.
      expect(vehicle.seats, 4);

      final body = VehicleModel.toJson(vehicle);
      expect(body['brand'], 'Toyota');
      expect(body['plate'], isNull);
    });
  });

  group('DriverProfileModel', () {
    test('fills in document types the response omitted', () {
      // §7 promises all four; the screen is built on that, so a short list is
      // padded rather than left with holes.
      final profile = DriverProfileModel.fromJson({
        'status': 'pending',
        'documents': [
          {'type': 'id_card', 'status': 'pending', 'needs_back_side': true},
        ],
      });

      expect(profile.documents, hasLength(DocumentType.values.length));
      expect(
        profile.documentOf(DocumentType.insurance).status,
        VerificationStatus.notUploaded,
      );
      expect(profile.documentOf(DocumentType.idCard).needsBackSide, isTrue);
      // Insurance is one-sided, and the fallback rule says so.
      expect(profile.documentOf(DocumentType.insurance).needsBackSide, isFalse);
    });

    // What approval does and does not gate is covered in
    // driver_publish_gate_test.dart; this only checks the car.
    test('canPublishRides needs a car', () {
      final approved = DriverProfileModel.fromJson({
        'status': 'approved',
        'vehicle': {'id': 3, 'brand': 'Toyota', 'model': 'Prius'},
        'documents': const [],
      });
      expect(approved.canPublishRides, isTrue);

      final noCar = DriverProfileModel.fromJson({
        'status': 'approved',
        'documents': const [],
      });
      expect(noCar.canPublishRides, isFalse);
    });
  });

  group('BookingModel', () {
    Map<String, dynamic> bookingJson(String status) => {
      'id': 88,
      'ride': {
        'id': 7,
        'from_city': {'id': 1, 'name': 'Bakı'},
        'to_city': {'id': 9, 'name': 'Qəbələ'},
        'departure_at': '2026-09-20T08:00:00+04:00',
        'total_seats': 4,
        'booked_seats': 2,
        'seats_left': 2,
        'price_per_seat': 15.0,
        'status': 'active',
        'created_at': '2026-09-15T09:00:00+04:00',
      },
      'seats': 2,
      'total_price': 30.0,
      'status': status,
      'message': 'İki nəfərik.',
      'passenger_reviewed': false,
      'driver_reviewed': false,
      'conversation_id': 14,
      'created_at': '2026-09-16T10:30:00+04:00',
      if (status == 'confirmed') 'contact_phone': '+994501234567',
    };

    test('exposes contact_phone only once the status unlocks it', () {
      expect(
        BookingModel.fromJson(bookingJson('confirmed')).contactPhone,
        '+994501234567',
      );
      // §10: on a pending booking the key is absent, not null.
      expect(
        BookingModel.fromJson(bookingJson('pending')).contactPhone,
        isNull,
      );
      expect(BookingModel.fromJson(bookingJson('pending')).hasContact, isFalse);
    });

    test('maps the snake_case statuses', () {
      expect(
        BookingModel.fromJson(bookingJson('cancelled_by_driver')).status,
        BookingStatus.cancelledByDriver,
      );
      expect(
        BookingStatus.cancelledByPassenger.apiValue,
        'cancelled_by_passenger',
      );
    });

    test('a cancelled booking locks its conversation', () {
      final booking = BookingModel.fromJson(bookingJson('cancelled_by_driver'));
      expect(booking.status.locksConversation, isTrue);
      expect(booking.status.holdsSeats, isFalse);
    });

    test('a completed trip owes a review from the side that is looking', () {
      // Departed yesterday, so well inside the fortnight §12 allows. This is
      // the booking the history tab offers to rate.
      final ride = {
        ...bookingJson('completed')['ride']! as Map<String, dynamic>,
        'departure_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'is_mine': false,
      };
      final json = {...bookingJson('completed'), 'ride': ride};

      final asPassenger = BookingModel.fromJson(json);
      expect(asPassenger.isMineAsDriver, isFalse);
      expect(asPassenger.needsMyReview, isTrue);

      // `passenger_reviewed` is this user's own flag, so it clears the debt…
      expect(
        BookingModel.fromJson({
          ...json,
          'passenger_reviewed': true,
        }).needsMyReview,
        isFalse,
      );
      // …while the driver's flag says nothing about what the passenger owes.
      expect(
        BookingModel.fromJson({...json, 'driver_reviewed': true}).needsMyReview,
        isTrue,
      );

      // The same booking seen by the driver reads the other flag.
      final asDriver = BookingModel.fromJson({
        ...json,
        'ride': {...ride, 'is_mine': true},
        'driver_reviewed': true,
      });
      expect(asDriver.needsMyReview, isFalse);
    });

    test('a review cannot be written before the trip is completed', () {
      expect(
        BookingModel.fromJson(bookingJson('confirmed')).needsMyReview,
        isFalse,
      );
    });
  });

  group('NotificationModel', () {
    test('reports a dead link when every target id is null', () {
      // §13: all three can be null at once, and the client must not open a
      // blank screen.
      final notification = NotificationModel.fromJson({
        'id': 120,
        'type': 'bookingConfirmed',
        'ride_id': null,
        'booking_id': null,
        'conversation_id': null,
        'created_at': '2026-09-16T12:00:00+04:00',
      });

      expect(notification.isDeadLink, isTrue);
      expect(notification.target, isA<NotificationTarget>());
    });

    test('prefers the conversation for a message notification', () {
      final notification = NotificationModel.fromJson({
        'id': 121,
        'type': 'newMessage',
        'booking_id': 88,
        'conversation_id': 14,
        'created_at': '2026-09-16T12:00:00+04:00',
      });

      expect(notification.target, isA<ConversationTarget>());
    });

    test('reads the payload extras', () {
      final notification = NotificationModel.fromJson({
        'id': 122,
        'type': 'bookingRequested',
        'payload': {'seats': 2},
        'created_at': '2026-09-16T12:00:00+04:00',
      });

      expect(notification.seats, 2);
    });

    test('reads an instant booking as the driver\'s own type', () {
      // Sent to the driver when a passenger books an instant-booking ride. It
      // used to arrive as `bookingConfirmed`, the passenger's wording.
      final notification = NotificationModel.fromJson({
        'id': 130,
        'type': 'bookingInstant',
        'ride_id': 7,
        'booking_id': 88,
        'conversation_id': null,
        'actor': {'id': 5, 'full_name': 'Aysel Həsənova'},
        'payload': {'seats': 2},
        'created_at': '2026-09-26T12:00:00+04:00',
      });

      expect(notification.type, NotificationType.bookingInstant);
      expect(notification.actor?.fullName, 'Aysel Həsənova');
      expect(notification.seats, 2);
      expect(notification.target, isA<BookingTarget>());
    });
  });

  group('ReviewModel', () {
    test('author_was_driver describes the author, not the target', () {
      // §12 calls this out specifically: false means a passenger wrote it, so
      // the review is *about* a driver.
      final review = ReviewModel.fromJson({
        'id': 55,
        'rating': 5,
        'author_was_driver': false,
        'comment': 'Vaxtında gəldi.',
        'created_at': '2026-09-16T12:00:00+04:00',
      });

      expect(review.authorWasDriver, isFalse);
      expect(review.isAboutDriver, isTrue);
      expect(review.targetRole, UserMode.driver);
    });
  });

  group('ChatMessageModel', () {
    test('trusts the server about who wrote a message', () {
      final message = ChatMessageModel.fromJson({
        'id': 301,
        'sender_id': 42,
        'is_mine': true,
        'text': 'Saat 8-də görüşürük.',
        'read_at': null,
        'created_at': '2026-09-16T12:00:00+04:00',
      });

      expect(message.isMine, isTrue);
      expect(message.isRead, isFalse);
    });
  });

}
