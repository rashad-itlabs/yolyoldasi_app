import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/failure.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/rides/data/repositories/ride_repository_impl.dart';
import 'package:yolyoldasi/features/rides/data/services/ride_api_service.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride_query.dart';
import 'package:yolyoldasi/features/rides/presentation/bloc/ride_browse/ride_browse_bloc.dart';

/// Browsing without searching: the passenger home lists every active ride, so
/// a route is optional on `GET /rides` and departed rides are dropped on the
/// way to the screen.
void main() {
  late _StubAdapter adapter;
  late RideRepositoryImpl rides;

  setUp(() {
    adapter = _StubAdapter();
    final client = ApiClient(
      tokens: InMemoryTokenStorage(),
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://example.test/api/v1',
    );
    rides = RideRepositoryImpl(RideApiService(client));
  });

  Map<String, dynamic> rideJson(int id, DateTime departureAt) => {
    'id': id,
    'driver': {
      'id': 42,
      'full_name': 'Rəşad M.',
      'has_driver_profile': true,
      'stats': {'driver_rating': 4.8, 'driver_review_count': 12},
    },
    'vehicle': {'id': 3, 'brand': 'Toyota', 'model': 'Prius', 'seats': 4},
    'from_city': {'id': 1, 'name': 'Bakı'},
    'to_city': {'id': 9, 'name': 'Qəbələ'},
    'departure_at': departureAt.toIso8601String(),
    'total_seats': 4,
    'booked_seats': 2,
    'seats_left': 2,
    'price_per_seat': 15.0,
    'status': 'active',
    'instant_booking': false,
    'is_mine': false,
    'created_at': DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> page(
    List<Map<String, dynamic>> items, {
    int currentPage = 1,
    int lastPage = 1,
  }) => {
    'data': items,
    'meta': {
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': 20,
      'total': items.length,
    },
  };

  final soon = DateTime.now().add(const Duration(hours: 6));
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final gone = DateTime.now().subtract(const Duration(hours: 2));

  group('GET /rides', () {
    test('a query with no route sends no city parameters', () async {
      adapter.reply(200, page(const []));
      await rides.search(const RideSearchQuery());

      final query = adapter.lastRequest!.queryParameters;
      expect(query.containsKey('from_city_id'), isFalse);
      expect(query.containsKey('to_city_id'), isFalse);

      // The rest of the query still goes: a browse list is still "rides with a
      // free seat, soonest first".
      expect(query['seats'], 1);
      expect(query['sort'], 'departure_at');
    });

    test('a picked route is still sent', () async {
      adapter.reply(200, page(const []));
      await rides.search(const RideSearchQuery(fromCityId: 1, toCityId: 9));

      final query = adapter.lastRequest!.queryParameters;
      expect(query['from_city_id'], 1);
      expect(query['to_city_id'], 9);
    });

    test('the same city at both ends never reaches the network', () async {
      // Nothing can match it, so there is no point spending a request to be
      // told so — the form produces this mid-swap.
      final result = await rides.search(
        const RideSearchQuery(fromCityId: 1, toCityId: 1),
      );

      expect((result as Err).failure, isA<ValidationFailure>());
      expect(adapter.lastRequest, isNull);
    });
  });

  group('RideBrowseBloc', () {
    test('lists active rides without being given a route', () async {
      adapter.reply(200, page([rideJson(1, soon), rideJson(2, tomorrow)]));

      final bloc = RideBrowseBloc(rides: rides);
      addTearDown(bloc.close);
      bloc.add(const RideBrowseRequested());
      await bloc.stream.firstWhere((state) => state.status.isSuccess);

      expect(bloc.state.rides.map((ride) => ride.id), [1, 2]);
      expect(
        adapter.lastRequest!.queryParameters.containsKey('from_city_id'),
        isFalse,
      );
    });

    test('a ride whose departure has passed is not listed', () async {
      // The server filters these, but a list loaded before a departure is
      // still on screen after it.
      adapter.reply(200, page([rideJson(1, gone), rideJson(2, tomorrow)]));

      final bloc = RideBrowseBloc(rides: rides);
      addTearDown(bloc.close);
      bloc.add(const RideBrowseRequested());
      await bloc.stream.firstWhere((state) => state.status.isSuccess);

      expect(bloc.state.rides.map((ride) => ride.id), [2]);
      // Only the *view* is filtered; the page keeps the server's cursor.
      expect(bloc.state.page.items, hasLength(2));
    });

    test('scrolling on appends the next page', () async {
      adapter.reply(200, page([rideJson(1, soon)], lastPage: 2));

      final bloc = RideBrowseBloc(rides: rides);
      addTearDown(bloc.close);
      bloc.add(const RideBrowseRequested());
      await bloc.stream.firstWhere((state) => state.status.isSuccess);
      expect(bloc.state.hasMore, isTrue);

      adapter.reply(
        200,
        page([rideJson(2, tomorrow)], currentPage: 2, lastPage: 2),
      );
      bloc.add(const RideBrowseMoreRequested());
      await bloc.stream.firstWhere((state) => state.page.items.length == 2);

      expect(bloc.state.rides.map((ride) => ride.id), [1, 2]);
      expect(adapter.lastRequest!.queryParameters['page'], 2);
      expect(bloc.state.hasMore, isFalse);
    });

    test('a 422 on the first page reads as "not supported yet"', () async {
      // What a backend that still insists on a route answers. The home screen
      // hides the section on this rather than showing an error nobody can act
      // on; a network failure, below, is a different matter.
      adapter.reply(422, {
        'message': 'The from city id field is required.',
        'errors': {
          'from_city_id': ['The from city id field is required.'],
        },
      });

      final bloc = RideBrowseBloc(rides: rides);
      addTearDown(bloc.close);
      bloc.add(const RideBrowseRequested());
      await bloc.stream.firstWhere((state) => state.status.isFailure);

      expect(bloc.state.isUnsupported, isTrue);
    });

    test('a failed first page keeps its failure retryable', () async {
      adapter.reply(500, {'message': 'boom'});

      final bloc = RideBrowseBloc(rides: rides);
      addTearDown(bloc.close);
      bloc.add(const RideBrowseRequested());
      await bloc.stream.firstWhere((state) => state.status.isFailure);

      expect(bloc.state.failure, isA<ServerFailure>());
      expect(bloc.state.isUnsupported, isFalse);
      expect(bloc.state.rides, isEmpty);
    });
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
