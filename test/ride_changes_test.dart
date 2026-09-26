import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/rides/data/repositories/ride_repository_impl.dart';
import 'package:yolyoldasi/features/rides/data/services/ride_api_service.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride_draft.dart';
import 'package:yolyoldasi/features/rides/presentation/bloc/my_rides/my_rides_bloc.dart';
import 'package:yolyoldasi/features/rides/presentation/bloc/ride_browse/ride_browse_bloc.dart';

/// A ride published from the form has to show up on the home tab on its own.
/// The lists there are loaded once and outlive the form, so they listen to
/// `RideRepository.changes` instead of waiting for a pull-to-refresh.
void main() {
  late _RoutedAdapter server;
  late RideRepositoryImpl rides;

  setUp(() {
    server = _RoutedAdapter();
    rides = RideRepositoryImpl(
      RideApiService(
        ApiClient(
          tokens: InMemoryTokenStorage(),
          dio: Dio()..httpClientAdapter = server,
          baseUrl: 'https://example.test/api/v1',
        ),
      ),
    );
  });

  final tomorrow = DateTime.now().add(const Duration(days: 1));

  Map<String, dynamic> rideJson(int id) => {
    'id': id,
    'driver': {'id': 42, 'full_name': 'Rəşad M.', 'has_driver_profile': true},
    'vehicle': {'id': 3, 'brand': 'Toyota', 'model': 'Prius', 'seats': 4},
    'from_city': {'id': 1, 'name': 'Bakı'},
    'to_city': {'id': 9, 'name': 'Qəbələ'},
    'departure_at': tomorrow.toIso8601String(),
    'total_seats': 3,
    'booked_seats': 0,
    'seats_left': 3,
    'price_per_seat': 15.0,
    'status': 'active',
    'instant_booking': false,
    'is_mine': true,
    'created_at': DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> page(List<int> ids) => {
    'data': [for (final id in ids) rideJson(id)],
    'meta': {
      'current_page': 1,
      'last_page': 1,
      'per_page': 20,
      'total': ids.length,
    },
  };

  final draft = RideDraft(
    vehicleId: 3,
    fromCityId: 1,
    toCityId: 9,
    date: tomorrow,
    timeOfDayMinutes: 9 * 60,
    pricePerSeat: 15,
  );

  /// Waits for [condition] rather than a fixed delay: the full suite runs
  /// files in parallel, and a timing guess that holds alone does not there.
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// For the checks that something did *not* happen.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  test('the driver list picks up a ride published elsewhere', () async {
    server.on('GET', '/rides/mine', 200, page([1]));
    final bloc = MyRidesBloc(rides: rides)..add(const MyRidesRequested());
    addTearDown(bloc.close);
    await until(() => bloc.state.status.isSuccess);
    expect(bloc.state.rides.map((r) => r.id), [1]);

    // The publish form writes through the same repository.
    server.on('POST', '/rides', 201, {'data': rideJson(2)});
    server.on('GET', '/rides/mine', 200, page([2, 1]));
    await rides.publish(draft);
    await until(() => bloc.state.rides.length == 2);

    expect(bloc.state.rides.map((r) => r.id), [2, 1]);
  });

  test('the passenger home list does too', () async {
    server.on('GET', '/rides', 200, page([1]));
    final bloc = RideBrowseBloc(rides: rides)..add(const RideBrowseRequested());
    addTearDown(bloc.close);
    await until(() => bloc.state.status.isSuccess);

    server.on('POST', '/rides', 201, {'data': rideJson(2)});
    server.on('GET', '/rides', 200, page([2, 1]));
    await rides.publish(draft);
    await until(() => bloc.state.page.items.length == 2);

    expect(bloc.state.page.items.map((r) => r.id), [2, 1]);
  });

  test('a failed write announces nothing', () async {
    var announced = 0;
    final subscription = rides.changes.listen((_) => announced++);
    addTearDown(subscription.cancel);

    server.on('POST', '/rides', 422, {'message': 'Sənədləriniz yoxlanılır.'});
    await rides.publish(draft);
    await settle();

    expect(announced, 0);
  });

  test('a failed re-read keeps the list on screen', () async {
    server.on('GET', '/rides/mine', 200, page([1]));
    final bloc = MyRidesBloc(rides: rides)..add(const MyRidesRequested());
    addTearDown(bloc.close);
    await until(() => bloc.state.status.isSuccess);

    server.on('POST', '/rides', 201, {'data': rideJson(2)});
    server.on('GET', '/rides/mine', 500, {'message': 'Server Error'});
    await rides.publish(draft);
    await settle();

    expect(bloc.state.rides.map((r) => r.id), [1]);
    expect(bloc.state.status.isFailure, isFalse);
  });
}

/// Answers by method and path, so a publish and the re-read after it can be
/// told apart.
class _RoutedAdapter implements HttpClientAdapter {
  final Map<String, (int, Object?)> _routes = {};

  void on(String method, String path, int status, Object? body) =>
      _routes['$method $path'] = (status, body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceFirst('/api/v1', '');
    final (status, body) = _routes['${options.method} $path'] ?? (404, null);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
