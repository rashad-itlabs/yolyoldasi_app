import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/cities/domain/entities/city.dart';
import 'package:yolyoldasi/features/profile/data/models/user_model.dart';
import 'package:yolyoldasi/features/profile/domain/entities/app_user.dart';
import 'package:yolyoldasi/features/profile/domain/entities/vehicle.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride.dart';
import 'package:yolyoldasi/features/rides/domain/repositories/ride_repository.dart';
import 'package:yolyoldasi/features/rides/presentation/pages/ride_detail_page.dart';

/// The ride screen opened by the driver who published it, against the same
/// screen opened by anybody else.
void main() {
  late _MockRides rides;
  late _MockSession session;

  setUpAll(initializeDateFormatting);

  setUp(() {
    rides = _MockRides();
    session = _MockSession();
    whenListen(
      session,
      const Stream<SessionState>.empty(),
      initialState: SessionState(
        status: SessionStatus.ready,
        user: UserModel.fromJson({
          'id': 42,
          'phone': '+994501234567',
          'full_name': 'Rəşad Məmmədov',
          'active_mode': 'driver',
          'has_driver_profile': true,
          'language_code': 'az',
        }),
      ),
    );
  });

  /// User 42's ride, with the plate only on their own copy — API.md §9
  /// returns it to the driver alone.
  Ride ride({required bool mine}) => Ride(
    id: 7,
    driver: const PublicUser(
      id: 42,
      fullName: 'Rəşad Məmmədov',
      hasDriverProfile: true,
    ),
    vehicle: Vehicle(
      id: 3,
      brand: 'Toyota',
      model: 'Prius',
      plate: mine ? '10-AB-123' : null,
    ),
    fromCity: const City(id: 1, name: 'Bakı'),
    toCity: const City(id: 2, name: 'Gəncə'),
    departureAt: DateTime.now().add(const Duration(days: 1)),
    totalSeats: 4,
    bookedSeats: 1,
    seatsLeft: 3,
    pricePerSeat: 15,
    status: RideStatus.active,
    createdAt: DateTime.now(),
    isMine: mine,
  );

  Future<void> open(WidgetTester tester, {required bool mine}) async {
    when(() => rides.byId(7)).thenAnswer((_) async => Ok(ride(mine: mine)));
    when(() => rides.changes).thenAnswer((_) => const Stream.empty());

    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepositoryProvider<RideRepository>.value(
        value: rides,
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
            home: const RideDetailPage(rideId: 7),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the driver is not shown themselves on their own ride', (
    tester,
  ) async {
    await open(tester, mine: true);

    expect(find.text('Rəşad M.'), findsNothing);
    expect(find.text('Sürücü'), findsNothing);
    // The note is about reaching the driver, which they are.
    expect(
      find.textContaining('telefon nömrəsi yalnız bron təsdiqlənəndən'),
      findsNothing,
    );

    // The car stays, plate and all: which one this ride is on still matters.
    expect(find.text('Avtomobil'), findsOneWidget);
    expect(find.textContaining('Toyota Prius'), findsOneWidget);
    expect(find.text('10-AB-123'), findsOneWidget);
    expect(find.text('Nömrə yalnız sizə görünür'), findsOneWidget);
  });

  testWidgets('everyone else sees the driver card with the car on it', (
    tester,
  ) async {
    await open(tester, mine: false);

    expect(find.text('Sürücü'), findsOneWidget);
    expect(find.text('Rəşad M.'), findsOneWidget);
    expect(find.textContaining('Toyota Prius'), findsOneWidget);
    expect(find.text('Avtomobil'), findsNothing);
    expect(find.text('Nömrə yalnız sizə görünür'), findsNothing);
  });
}

class _MockRides extends Mock implements RideRepository {}

class _MockSession extends MockBloc<SessionEvent, SessionState>
    implements SessionBloc {}
