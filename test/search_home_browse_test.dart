import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/network/api_envelope.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/bookings/domain/entities/booking.dart';
import 'package:yolyoldasi/features/bookings/domain/repositories/booking_repository.dart';
import 'package:yolyoldasi/features/cities/domain/entities/city.dart';
import 'package:yolyoldasi/features/cities/domain/repositories/city_repository.dart';
import 'package:yolyoldasi/features/cities/presentation/bloc/cities_bloc.dart';
import 'package:yolyoldasi/features/profile/domain/entities/app_user.dart';
import 'package:yolyoldasi/features/ride_requests/domain/entities/ride_request.dart';
import 'package:yolyoldasi/features/ride_requests/domain/repositories/ride_request_repository.dart';
import 'package:yolyoldasi/features/rides/data/models/ride_model.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride_query.dart';
import 'package:yolyoldasi/features/rides/domain/repositories/ride_repository.dart';
import 'package:yolyoldasi/features/rides/presentation/bloc/ride_search/ride_search_bloc.dart';
import 'package:yolyoldasi/features/rides/presentation/pages/search_home_page.dart';
import 'package:yolyoldasi/features/rides/presentation/widgets/ride_card.dart';
import 'package:yolyoldasi/features/shell/presentation/bloc/badges/badges_bloc.dart';

/// The passenger home lists every active ride on its own, without anybody
/// filling in the search form first.
void main() {
  Ride ride(int id, DateTime departureAt) => RideModel.fromJson({
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
  });

  /// [user] decides whether the screen is built for a guest or for an account.
  ///
  /// The default is a guest, because browsing without one is the normal entry
  /// path now (API.md §18).
  Widget wrap(List<Ride> rides, {AppUser? user}) {
    final repository = _FakeRideRepository(rides);

    final session = _MockSessionBloc();
    whenListen(
      session,
      const Stream<SessionState>.empty(),
      initialState: SessionState(
        status: user == null ? SessionStatus.signedOut : SessionStatus.ready,
        user: user,
      ),
    );

    final badges = _MockBadgesBloc();
    whenListen(
      badges,
      const Stream<BadgesState>.empty(),
      initialState: const BadgesState(),
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RideRepository>.value(value: repository),
        RepositoryProvider<CityRepository>.value(value: _FakeCityRepository()),
        RepositoryProvider<BookingRepository>.value(
          value: _FakeBookingRepository(),
        ),
        // Only the signed-in branch reaches for it — the "what I'm waiting
        // for" card — but the provider has to be above the tree either way.
        RepositoryProvider<RideRequestRepository>.value(
          value: _FakeRideRequestRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SessionBloc>.value(value: session),
          BlocProvider<BadgesBloc>.value(value: badges),
          BlocProvider<CitiesBloc>(
            create: (_) => CitiesBloc(cities: _FakeCityRepository()),
          ),
          BlocProvider<RideSearchBloc>(
            create: (_) => RideSearchBloc(rides: repository),
          ),
        ],
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
          home: const SearchHomePage(),
        ),
      ),
    );
  }

  /// A tall window, because the list is lazy: on the default 800×600 surface
  /// only the first card is ever built, and counting them proves nothing.
  void tallWindow(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1200, 4500)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  /// One frame to build, one for the repository's answer, then the cards'
  /// entry animation.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('shows the active rides without a search', (tester) async {
    tallWindow(tester);
    await tester.pumpWidget(
      wrap([
        ride(1, DateTime.now().add(const Duration(hours: 6))),
        ride(2, DateTime.now().add(const Duration(days: 1))),
      ]),
    );
    await settle(tester);

    expect(find.text('Bütün aktiv elanlar'), findsOneWidget);
    expect(find.byType(RideCard), findsNWidgets(2));
  });

  testWidgets('a ride that has already left is not shown', (tester) async {
    tallWindow(tester);
    await tester.pumpWidget(
      wrap([
        ride(1, DateTime.now().subtract(const Duration(hours: 2))),
        ride(2, DateTime.now().add(const Duration(days: 1))),
      ]),
    );
    await settle(tester);

    expect(find.byType(RideCard), findsOneWidget);
  });

  testWidgets('a page of nothing but departed rides reads as empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap([ride(1, DateTime.now().subtract(const Duration(minutes: 5)))]),
    );
    await settle(tester);

    expect(find.text('Hazırda aktiv elan yoxdur'), findsOneWidget);
    expect(find.byType(RideCard), findsNothing);
  });

  testWidgets('says so when there is nothing on offer', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await settle(tester);

    expect(find.text('Hazırda aktiv elan yoxdur'), findsOneWidget);
    expect(find.byType(RideCard), findsNothing);
  });

  testWidgets('offers a guest no notification bell', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    // `/notifications` needs an account, so the router would bounce a guest
    // straight back here — a button that visibly does nothing is worse than no
    // button. Same for the avatar, which has no profile to open.
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
  });

  testWidgets('gives a signed-in user the bell back', (tester) async {
    await tester.pumpWidget(
      wrap(const [], user: const AppUser(id: 7, phone: '+994501234567')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });

  testWidgets('invites a passenger with no requests to post one', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const [], user: const AppUser(id: 7, phone: '+994501234567')),
    );
    await tester.pumpAndSettle();

    // The entry point to a *first* request has to exist before there is one.
    // Hidden-when-empty meant the only other way in was an empty search
    // result, which is a screen you reach only on a dead route — so anyone
    // searching a busy corridor never learned the feature was there.
    expect(find.text('Axtardığını tapmırsan?'), findsOneWidget);
  });

  testWidgets('holds the status bar open so the list cannot scroll under it', (
    tester,
  ) async {
    // The screen has no app bar. Without something pinned at the top, the
    // ride cards scroll up behind the clock and the battery.
    tallWindow(tester);
    tester.view.padding = const FakeViewPadding(top: 141); // 47dp at dpr 3

    await tester.pumpWidget(
      wrap([ride(1, DateTime.now().add(const Duration(hours: 6)))]),
    );
    await settle(tester);

    final header = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(header.pinned, isTrue);
    expect(header.delegate.minExtent, 47);
    // Pinned *and* unshrinkable: the strip is the full inset at every offset.
    expect(header.delegate.maxExtent, header.delegate.minExtent);
  });

  testWidgets('the strip is the same colour as the header under it', (
    tester,
  ) async {
    tallWindow(tester);
    tester.view.padding = const FakeViewPadding(top: 141);

    await tester.pumpWidget(wrap(const []));
    await settle(tester);

    final strip = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(SliverPersistentHeader),
        matching: find.byType(ColoredBox),
      ),
    );

    final hero = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.gradient is LinearGradient);
    final gradient = hero.gradient! as LinearGradient;

    // Straight down, so the header's top row is one flat colour rather than a
    // ramp the strip above it could only approximate.
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(strip.color, gradient.colors.first);
  });

  testWidgets('leaves the strip out when there is no status bar', (
    tester,
  ) async {
    // A zero-extent sliver would be pure overhead, and some surfaces (and
    // every widget test that does not ask for one) have no inset at all.
    tallWindow(tester);

    await tester.pumpWidget(wrap(const []));
    await settle(tester);

    expect(find.byType(SliverPersistentHeader), findsNothing);
  });
}

/// Answers `mine` with nothing: the home screen only asks so it can hide the
/// card when there is nothing waiting.
class _FakeRideRequestRepository implements RideRequestRepository {
  @override
  FutureResult<Paginated<RideRequest>> mine({
    RideRequestStatus? status,
    int? page,
  }) async => Ok(const Paginated<RideRequest>.empty());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState>
    implements SessionBloc {}

class _MockBadgesBloc extends MockBloc<BadgesEvent, BadgesState>
    implements BadgesBloc {}

/// Answers `search` and `recentSearches`; the home screen asks for nothing
/// else, and `noSuchMethod` makes the rest of the interface a compile-time
/// non-issue rather than a wall of throwing stubs.
class _FakeRideRepository implements RideRepository {
  _FakeRideRepository(this._rides);

  final List<Ride> _rides;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  FutureResult<Paginated<Ride>> search(
    RideSearchQuery query, {
    int? page,
  }) async => Ok(Paginated(items: _rides, meta: PageMeta.single));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookingRepository implements BookingRepository {
  @override
  FutureResult<Paginated<Booking>> mine({
    BookingStatus? status,
    int? page,
  }) async => const Ok(Paginated<Booking>.empty());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCityRepository implements CityRepository {
  static const List<City> _cities = [
    City(id: 1, name: 'Bakı'),
    City(id: 9, name: 'Qəbələ'),
  ];

  @override
  FutureResult<List<City>> all() async => const Ok(_cities);

  @override
  City? byId(int? id) => _cities.where((city) => city.id == id).firstOrNull;

  @override
  List<City>? search(String query, String languageCode) => _cities;

  @override
  void invalidate() {}
}
