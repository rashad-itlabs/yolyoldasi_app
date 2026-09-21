import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/network/api_envelope.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/core/types.dart';
import 'package:yolyoldasi/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yolyoldasi/features/auth/data/services/auth_api_service.dart';
import 'package:yolyoldasi/features/auth/domain/entities/auth_session.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/bookings/data/models/booking_model.dart';
import 'package:yolyoldasi/features/bookings/domain/entities/booking.dart';
import 'package:yolyoldasi/features/bookings/domain/repositories/booking_repository.dart';
import 'package:yolyoldasi/features/profile/data/repositories/user_repository_impl.dart';
import 'package:yolyoldasi/features/profile/data/services/device_token_api_service.dart';
import 'package:yolyoldasi/features/profile/data/services/user_api_service.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';
import 'package:yolyoldasi/features/profile/domain/repositories/user_repository.dart';
import 'package:yolyoldasi/features/profile/presentation/pages/public_profile_page.dart';
import 'package:yolyoldasi/features/reviews/data/repositories/review_repository_impl.dart';
import 'package:yolyoldasi/features/reviews/data/services/review_api_service.dart';
import 'package:yolyoldasi/features/reviews/domain/repositories/review_repository.dart';
import 'package:yolyoldasi/features/settings/domain/repositories/settings_repository.dart';

/// What a passenger sees when they tap the driver on a ride: `GET /users/{id}`
/// and that person's reviews, on one screen.
void main() {
  late _StubAdapter adapter;

  /// Built inside each test rather than in `setUp`: a bloc created outside the
  /// tester's async zone keeps its stream there too.
  ///
  /// [bookings] is what `GET /bookings?status=completed` answers with, which
  /// is how the page decides whether a review is owed.
  ///
  /// [signedIn] drives the session the page is built under. It defaults to
  /// `true` because everything this file asserts is about a viewer with an
  /// account: the page is reachable without one (API.md §18), but "you still
  /// owe this person a review" is a statement about the viewer's own bookings
  /// and can only ever be false for a guest.
  Widget wrap({List<Json> bookings = const [], bool signedIn = true}) {
    final tokens = InMemoryTokenStorage();
    final client = ApiClient(
      tokens: tokens,
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://example.test/api/v1',
    );
    final users = UserRepositoryImpl(
      users: UserApiService(client),
      deviceTokens: DeviceTokenApiService(client),
    );
    final reviews = ReviewRepositoryImpl(ReviewApiService(client));
    final bookingRepository = _FakeBookingRepository(bookings);
    final session = SessionBloc(
      auth: AuthRepositoryImpl(
        api: AuthApiService(client),
        deviceTokens: DeviceTokenApiService(client),
        tokens: tokens,
        unauthorized: client.onUnauthorized,
      ),
      users: users,
      settings: _FakeSettingsRepository(),
    );
    addTearDown(session.close);

    if (signedIn) {
      // `SessionSignedIn` reads `/me` to fill the profile, so the stub has to
      // be in place before the event lands.
      adapter.on('/me', 200, {
        'data': {'id': 7, 'phone': '+994501234567', 'full_name': 'Sərnişin'},
      });
      session.add(
        const SessionSignedIn(
          AuthSession(token: 'test-token', userId: 7),
          mode: UserMode.passenger,
        ),
      );
    }

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<UserRepository>.value(value: users),
        RepositoryProvider<ReviewRepository>.value(value: reviews),
        RepositoryProvider<BookingRepository>.value(value: bookingRepository),
      ],
      child: BlocProvider<SessionBloc>.value(
        value: session,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('az'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const PublicProfilePage(userId: 42),
        ),
      ),
    );
  }

  /// The driver object API.md §9 embeds in a ride, returned whole by
  /// `GET /users/{id}`.
  Map<String, dynamic> driver() => {
    'data': {
      'id': 42,
      'full_name': 'Rəşad Məmmədov',
      'photo_url': null,
      'gender': 'male',
      'birth_year': 1994,
      'city': {'id': 1, 'name': 'Bakı'},
      'has_driver_profile': true,
      'stats': {
        'driver_rating': 4.8,
        'driver_review_count': 12,
        'driver_trip_count': 15,
        'passenger_rating': 5.0,
        'passenger_review_count': 3,
        'passenger_trip_count': 4,
      },
    },
  };

  Map<String, dynamic> reviews() => {
    'data': [
      {
        'id': 55,
        'author': {'id': 9, 'full_name': 'Aysel Kərimova'},
        'rating': 5,
        'author_was_driver': false,
        'comment': 'Vaxtında gəldi.',
        'created_at': '2026-09-16T12:00:00+04:00',
      },
    ],
  };

  /// A trip with user 42 that has already run and that this passenger has not
  /// rated: `is_mine: false` on the ride puts the viewer in the passenger
  /// seat, so `passenger_reviewed` is the flag that counts.
  Json completedTrip({bool reviewed = false}) => {
    'id': 88,
    'ride': {
      'id': 7,
      'from_city': {'id': 1, 'name': 'Bakı'},
      'to_city': {'id': 9, 'name': 'Qəbələ'},
      'departure_at': DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
      'total_seats': 4,
      'booked_seats': 2,
      'seats_left': 2,
      'price_per_seat': 15.0,
      'status': 'completed',
      'is_mine': false,
      'created_at': '2026-09-15T09:00:00+04:00',
    },
    'driver': {'id': 42, 'full_name': 'Rəşad Məmmədov'},
    'seats': 2,
    'total_price': 30.0,
    'status': 'completed',
    'passenger_reviewed': reviewed,
    'driver_reviewed': false,
    'created_at': '2026-09-16T10:30:00+04:00',
  };

  setUp(() => adapter = _StubAdapter());

  /// The default 800×600 surface leaves the tab body ~120px tall, which is
  /// shorter than any of its states. A phone-shaped window keeps the test
  /// about the screen rather than about the test harness.
  void phoneWindow(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows the driver once /users/{id} answers', (tester) async {
    adapter
      ..on('/users/42/reviews', 200, reviews())
      ..on('/users/42', 200, driver());

    phoneWindow(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Rəşad M.'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    // driver_trip_count + passenger_trip_count.
    expect(find.text('19'), findsOneWidget);
    expect(find.text('Bakı'), findsOneWidget);
    // "Sürücü", not "Sürücü rejimi" — a mode is something you switch on your
    // own account, and this is somebody else's profile.
    expect(find.text('Sürücü'), findsOneWidget);
    expect(find.text('Sürücü rejimi'), findsNothing);
  });

  testWidgets('puts the reviews in one list rather than behind tabs', (
    tester,
  ) async {
    adapter
      ..on('/users/42/reviews', 200, reviews())
      ..on('/users/42', 200, driver());

    phoneWindow(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Vaxtında gəldi.'), findsOneWidget);
  });

  testWidgets('offers to rate a trip this driver is still owed one for', (
    tester,
  ) async {
    adapter
      ..on('/users/42/reviews', 200, reviews())
      ..on('/users/42', 200, driver());

    phoneWindow(tester);
    await tester.pumpWidget(wrap(bookings: [completedTrip()]));
    await tester.pumpAndSettle();

    expect(find.text('Səfəri qiymətləndirin'), findsOneWidget);
  });

  testWidgets('offers nothing to rate without a trip that owes one', (
    tester,
  ) async {
    adapter
      ..on('/users/42/reviews', 200, reviews())
      ..on('/users/42', 200, driver());

    phoneWindow(tester);

    // No shared trip at all.
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Səfəri qiymətləndirin'), findsNothing);

    // A trip, but one this passenger has already rated. `POST /bookings/{id}
    // /reviews` answers 409 for a second attempt (API.md §12), so the button
    // must not be there to press.
    await tester.pumpWidget(wrap(bookings: [completedTrip(reviewed: true)]));
    await tester.pumpAndSettle();
    expect(find.text('Səfəri qiymətləndirin'), findsNothing);
  });

  testWidgets('opens for a guest without asking for their bookings', (
    tester,
  ) async {
    adapter
      ..on('/users/42/reviews', 200, reviews())
      ..on('/users/42', 200, driver());

    phoneWindow(tester);
    await tester.pumpWidget(wrap(signedIn: false));
    await tester.pumpAndSettle();

    // The page itself works with no account (API.md §18) …
    expect(find.text('Rəşad M.'), findsOneWidget);

    // … and does not spend a guaranteed 401 on `GET /bookings`, which would
    // reach the session as "your session expired" for someone who never had
    // one.
    expect(find.text('Səfəri qiymətləndirin'), findsNothing);
  });

  testWidgets('a profile whose reviews failed still renders', (tester) async {
    // The header is the part the passenger came for; a 500 on the review list
    // must not blank the whole screen.
    adapter
      ..on('/users/42/reviews', 500, {'message': 'Server xətası.'})
      ..on('/users/42', 200, driver());

    phoneWindow(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Rəşad M.'), findsOneWidget);
  });

  testWidgets('a stats block the API left out is not a blank screen', (
    tester,
  ) async {
    // §16.5: keys go missing rather than arriving null, and a profile with no
    // ratings yet is the common case.
    final bare = {
      'data': {'id': 42, 'full_name': 'Rəşad Məmmədov'},
    };
    adapter
      ..on('/users/42/reviews', 200, {'data': const []})
      ..on('/users/42', 200, bare);

    phoneWindow(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Rəşad M.'), findsOneWidget);
  });
}

/// Dio adapter that answers by path, so one test can script both
/// `GET /users/{id}` and that user's reviews. Paths are matched with
/// `endsWith` and the most recently added matching rule wins.
class _StubAdapter implements HttpClientAdapter {
  final List<({String path, int status, Object? body})> _rules = [];
  final List<RequestOptions> requests = [];

  void on(String path, int status, Object? body) =>
      _rules.add((path: path, status: status, body: body));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final rule = _rules.where((r) => options.path.endsWith(r.path)).lastOrNull;
    return ResponseBody.fromString(
      rule?.body == null ? '{}' : jsonEncode(rule!.body),
      rule?.status ?? 404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Answers `mine`, which is the only call the profile makes: the signed-in
/// user is a passenger here, so their own bookings are the ones that could owe
/// this driver a review.
class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository(this._bookings);

  final List<Json> _bookings;

  @override
  FutureResult<Paginated<Booking>> mine({
    BookingStatus? status,
    int? page,
  }) async =>
      Ok(Paginated.fromBody({'data': _bookings}, BookingModel.fromJson));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  bool get onboardingSeen => true;

  @override
  ThemeMode get themeMode => ThemeMode.system;

  @override
  String? get languageCode => null;

  @override
  Future<void> load() async {}

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  Future<void> setLanguageCode(String? code) async {}

  @override
  Future<void> setOnboardingSeen(bool seen) async {}

  @override
  Future<void> clearForSignOut() async {}

  @override
  String? get dismissedUpdateVersion => null;

  @override
  Future<void> setDismissedUpdateVersion(String? version) async {}
}
