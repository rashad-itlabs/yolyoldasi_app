import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/failure.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_strings.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/core/utils/failure_message.dart';
import 'package:yolyoldasi/features/bookings/data/repositories/booking_repository_impl.dart';
import 'package:yolyoldasi/features/bookings/data/services/booking_api_service.dart';
import 'package:yolyoldasi/features/bookings/domain/entities/booking.dart';
import 'package:yolyoldasi/features/bookings/presentation/bloc/booking_request/booking_request_bloc.dart';
import 'package:yolyoldasi/features/bookings/presentation/bloc/bookings_list/bookings_list_bloc.dart';

/// The passenger side of `POST /rides/{id}/bookings` (API.md §10), from the
/// request sheet's bloc down to the wire.
void main() {
  late _StubAdapter adapter;
  late BookingRepositoryImpl bookings;

  setUp(() {
    adapter = _StubAdapter();
    final client = ApiClient(
      tokens: InMemoryTokenStorage(),
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://example.test/api/v1',
    );
    bookings = BookingRepositoryImpl(BookingApiService(client));
  });

  /// [departureAt] is worth passing whenever an assertion turns on the ride
  /// still being ahead — a literal date makes such a test pass until it
  /// silently stops being in the future.
  Map<String, dynamic> created({
    String status = 'pending',
    String departureAt = '2026-09-20T08:00:00+04:00',
  }) => {
    'data': {
      'id': 88,
      'ride': {
        'id': 7,
        'from_city': {'id': 1, 'name': 'Bakı'},
        'to_city': {'id': 9, 'name': 'Qəbələ'},
        'departure_at': departureAt,
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
      'conversation_id': 14,
      'created_at': '2026-09-16T10:30:00+04:00',
    },
  };

  BookingRequestBloc openSheet() {
    final bloc = BookingRequestBloc(bookings: bookings)
      ..add(
        const BookingRequestStarted(
          rideId: 7,
          seatsAvailable: 3,
          pricePerSeat: 15.0,
        ),
      );
    addTearDown(bloc.close);
    return bloc;
  }

  test('a request reaches the ride and carries seats and message', () async {
    adapter.reply(201, created());

    final bloc = openSheet()
      ..add(const BookingRequestSeatsChanged(2))
      ..add(const BookingRequestMessageChanged('İki nəfərik.'))
      ..add(const BookingRequestSubmitted());
    await bloc.stream.firstWhere((state) => state.status.isSuccess);

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, contains('/rides/7/bookings'));

    final sent = adapter.lastRequest?.data as Map<String, dynamic>;
    expect(sent['seats'], 2);
    expect(sent['message'], 'İki nəfərik.');

    // The sheet pops with this id and the detail screen opens on it.
    expect(bloc.state.createdBooking?.id, 88);
  });

  test('an empty message is left out rather than sent blank', () async {
    adapter.reply(201, created());

    final bloc = openSheet()..add(const BookingRequestSubmitted());
    await bloc.stream.firstWhere((state) => state.status.isSuccess);

    final sent = adapter.lastRequest?.data as Map<String, dynamic>;
    expect(sent.containsKey('message'), isFalse);
    expect(sent['seats'], 1);
  });

  test('instant booking comes back confirmed', () async {
    // §10: with `instant_booking` the seat is taken on the spot, so the sheet
    // gets a `confirmed` booking rather than a `pending` one.
    adapter.reply(201, created(status: 'confirmed'));

    final bloc = openSheet()..add(const BookingRequestSubmitted());
    await bloc.stream.firstWhere((state) => state.status.isSuccess);

    expect(bloc.state.createdBooking?.status.name, 'confirmed');
  });

  test('a refused second request is a 409 no retry can fix', () async {
    // §10: an active booking, or a driver who has decided. The sheet explains
    // it inline instead of offering "try again".
    adapter.reply(409, {'message': 'Bu səfərə artıq müraciət etmisən.'});

    final bloc = openSheet()..add(const BookingRequestSubmitted());
    await bloc.stream.firstWhere((state) => state.status.isFailure);

    final failure = bloc.state.failure;
    expect(failure, isA<ConflictFailure>());
    expect(failure?.isRetryable, isFalse);
    expect(bloc.state.createdBooking, isNull);

    // There is more than one way to earn this 409 now, so the server's own
    // wording is what the banner shows.
    expect(
      bloc.state.duplicateMessage(AppStrings.of('az')),
      'Bu səfərə artıq müraciət etmisən.',
    );
  });

  test('a 409 with no prose still says something useful', () async {
    adapter.reply(409, <String, dynamic>{});

    final bloc = openSheet()..add(const BookingRequestSubmitted());
    await bloc.stream.firstWhere((state) => state.status.isFailure);

    final l10n = AppStrings.of('az');
    expect(bloc.state.duplicateMessage(l10n), l10n.alreadyRequestedBody);
  });

  /// A departure the assertions can rely on being ahead of `DateTime.now()`.
  String inAWeek() =>
      DateTime.now().add(const Duration(days: 7)).toIso8601String();

  test('cancelling carries the reason and comes back cancelled', () async {
    // §10: the passenger walks away — either the trip is off, or a cheaper
    // ride turned up. The reason is the only thing the driver sees afterwards.
    adapter.reply(
      200,
      created(status: 'cancelled_by_passenger', departureAt: inAWeek()),
    );

    final result = await bookings.cancel(
      88,
      reason: 'Daha sərfəli səfər tapdım',
    );

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, contains('/bookings/88/cancel'));

    final sent = adapter.lastRequest?.data as Map<String, dynamic>;
    expect(sent['reason'], 'Daha sərfəli səfər tapdım');

    final booking = (result as Ok<Booking>).value;
    expect(booking.status, BookingStatus.cancelledByPassenger);
    expect(booking.status.holdsSeats, isFalse);

    // Their own "no" is not final: the ride still has room, so the way back is
    // offered rather than a consolation search.
    expect(booking.canCancel, isFalse);
    expect(booking.canRebookSameRide, isTrue);
    expect(booking.needsAnotherRide, isFalse);
  });

  test('a full ride is not offered back after cancelling', () async {
    // The seat went to someone else in the meantime, which is exactly what the
    // cancel sheet warns about — so the card must not promise it back.
    adapter.reply(200, {
      'data': {
        ...created(
          status: 'cancelled_by_passenger',
          departureAt: inAWeek(),
        )['data']!,
        'ride': {
          ...(created()['data']! as Map<String, dynamic>)['ride']!
              as Map<String, dynamic>,
          'departure_at': inAWeek(),
          'booked_seats': 4,
          'seats_left': 0,
        },
      },
    });

    final result = await bookings.byId(88);
    final booking = (result as Ok<Booking>).value;

    expect(booking.ride.isFull, isTrue);
    expect(booking.canRebookSameRide, isFalse);
  });

  test('a cancellation with no reason sends no blank field', () async {
    adapter.reply(200, created(status: 'cancelled_by_passenger'));

    await bookings.cancel(88, reason: '   ');

    final sent = adapter.lastRequest?.data as Map<String, dynamic>;
    expect(sent.containsKey('reason'), isFalse);
  });

  test('the cancel sheet offers each side its own reasons', () {
    // "The driver is not responding" is not something a driver cancels over,
    // and free text is always the last way out.
    final passenger = BookingCancelReason.presetsFor(asDriver: false);
    final driver = BookingCancelReason.presetsFor(asDriver: true);

    expect(passenger, contains(BookingCancelReason.foundCheaper));
    expect(passenger, contains(BookingCancelReason.noAnswer));
    expect(driver, isNot(contains(BookingCancelReason.noAnswer)));
    expect(driver, contains(BookingCancelReason.vehicleProblem));

    for (final presets in [passenger, driver]) {
      expect(presets.last, BookingCancelReason.other);
      expect(presets.where((r) => r.isFreeText), hasLength(1));
    }
  });

  test('the driver can shut the ride to a passenger who cancelled', () async {
    // The veto: a cancellation reopens the ride by default, and this is how
    // the driver — the one whose seat it is — takes that back.
    adapter.reply(200, {
      'data': {
        ...created(
          status: 'cancelled_by_passenger',
          departureAt: inAWeek(),
        )['data']!,
        'passenger_blocked': true,
      },
    });

    final result = await bookings.blockPassenger(88);

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, contains('/bookings/88/block'));

    final booking = (result as Ok<Booking>).value;
    expect(booking.passengerBlocked, isTrue);

    // The status is untouched, so only the flag can say what happened — which
    // is why the screens key their message on the action.
    expect(booking.status, BookingStatus.cancelledByPassenger);

    // And the way back closes for the passenger.
    expect(booking.canRebookSameRide, isFalse);
    expect(booking.needsAnotherRide, isTrue);
    expect(booking.isClosedByDriver, isTrue);
  });

  test('unblocking reopens the ride to that passenger', () async {
    adapter.reply(
      200,
      created(status: 'cancelled_by_passenger', departureAt: inAWeek()),
    );

    final result = await bookings.unblockPassenger(88);

    expect(adapter.lastRequest?.path, contains('/bookings/88/unblock'));

    final booking = (result as Ok<Booking>).value;
    expect(booking.passengerBlocked, isFalse);
    expect(booking.canRebookSameRide, isTrue);
  });

  test('a driver who said no closes the ride for good', () async {
    // Whoever said "no" decides whether the door reopens: the driver's answer
    // is final, so the passenger is sent to the route, not back to the ride.
    for (final status in ['rejected', 'cancelled_by_driver']) {
      adapter.reply(200, created(status: status, departureAt: inAWeek()));

      final result = await bookings.byId(88);
      final booking = (result as Ok<Booking>).value;

      expect(booking.needsAnotherRide, isTrue, reason: status);
      expect(booking.canRebookSameRide, isFalse, reason: status);
    }
  });

  test('the bookings screen can reach both collections', () async {
    // A driver is a passenger too. Their own confirmed seat lives in
    // `GET /bookings`, not in `/bookings/incoming`, so the screen has to be
    // able to switch without the user flipping the whole app's mode.
    adapter.reply(200, {
      'data': [created()['data']],
      'meta': {'current_page': 1, 'last_page': 1},
    });

    final bloc = BookingsListBloc(bookings: bookings)
      ..add(const BookingsListRequested());
    addTearDown(bloc.close);

    await bloc.stream.firstWhere((state) => state.status.isSuccess);
    expect(adapter.lastRequest?.path, endsWith('/bookings'));

    bloc.add(const BookingsListScopeChanged(BookingScope.incoming));
    await bloc.stream.firstWhere(
      (state) => state.scope.isIncoming && state.status.isSuccess,
    );
    expect(adapter.lastRequest?.path, endsWith('/bookings/incoming'));

    bloc.add(const BookingsListScopeChanged(BookingScope.mine));
    await bloc.stream.firstWhere(
      (state) => !state.scope.isIncoming && state.status.isSuccess,
    );
    expect(adapter.lastRequest?.path, endsWith('/bookings'));
  });

  test('a confirmed booking lands in the upcoming half', () async {
    // The two tabs are split client-side, so this is the rule that decides
    // whether a confirmed seat is visible at all.
    adapter.reply(200, created(status: 'confirmed', departureAt: inAWeek()));

    final result = await bookings.byId(88);
    final booking = (result as Ok<Booking>).value;

    expect(booking.status.isActive, isTrue);
    expect(booking.isUpcoming, isTrue);
  });

  test('more seats than are free never leave the sheet', () async {
    adapter.reply(201, created());

    final bloc = openSheet()..add(const BookingRequestSeatsChanged(9));
    await Future<void>.delayed(Duration.zero);

    // Clamped to what the ride has left, so the 422 is avoided rather than
    // reported.
    expect(bloc.state.request.seats, 3);
  });
}

/// Minimal Dio adapter that replays one canned response.
class _StubAdapter implements HttpClientAdapter {
  int _status = 200;
  Object? _body;
  RequestOptions? lastRequest;

  void reply(int status, Object? body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      _body == null ? '' : jsonEncode(_body),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
