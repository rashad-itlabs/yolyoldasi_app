import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/bloc/data_status.dart';
import 'package:yolyoldasi/core/error/failure.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/network/upload_file.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/core/widgets/pro_badge.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/session/session_bloc.dart';
import 'package:yolyoldasi/features/profile/data/models/driver_profile_model.dart';
import 'package:yolyoldasi/features/profile/data/models/user_model.dart';
import 'package:yolyoldasi/features/profile/domain/entities/driver_profile.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';
import 'package:yolyoldasi/features/profile/domain/entities/vehicle.dart';
import 'package:yolyoldasi/features/profile/domain/repositories/driver_repository.dart';
import 'package:yolyoldasi/features/profile/presentation/bloc/driver_profile/driver_profile_bloc.dart';
import 'package:yolyoldasi/features/profile/presentation/pages/pro_page.dart';
import 'package:yolyoldasi/features/rides/data/models/ride_model.dart';
import 'package:yolyoldasi/features/rides/presentation/widgets/ride_card.dart';

/// The driver PRO tier: what the app reads from the API, the trial, the PRO
/// screen's four states, and the badge and boost on ride cards.
void main() {
  group('reading PRO from the API', () {
    test('a pro block becomes the driver\'s PRO status', () {
      final profile = _profile(
        pro: {
          'active': true,
          'until': '2026-11-16T12:00:00+04:00',
          'trial_available': false,
          'trial_days': 30,
        },
      );

      expect(profile.isPro, isTrue);
      expect(profile.pro!.until, isNotNull);
      expect(profile.pro!.trialAvailable, isFalse);
      expect(profile.pro!.trialDays, 30);
    });

    test('an API from before PRO leaves it unknown, not "inactive"', () {
      final profile = _profile();

      expect(profile.pro, isNull);
      expect(profile.isPro, isFalse);
    });

    test('a driver shown on a ride carries the badge only when told', () {
      expect(_driver(isPro: true).showsProBadge, isTrue);
      expect(_driver(isPro: false).showsProBadge, isFalse);

      final unknown = _driver();
      expect(unknown.isPro, isNull);
      expect(unknown.showsProBadge, isFalse);
    });
  });

  group('starting the free trial', () {
    blocTest<DriverProfileBloc, DriverProfileState>(
      'lands the new profile and reports success',
      build: () => DriverProfileBloc(drivers: _FakeDrivers()),
      act: (bloc) => bloc.add(const DriverProTrialStarted()),
      expect: () => [
        isA<DriverProfileState>().having(
          (s) => s.proTrialStatus,
          'status',
          ActionStatus.inProgress,
        ),
        isA<DriverProfileState>()
            .having((s) => s.proTrialStatus, 'status', ActionStatus.success)
            .having((s) => s.profile?.isPro, 'isPro', isTrue),
      ],
    );

    blocTest<DriverProfileBloc, DriverProfileState>(
      'a refusal keeps the profile and says why',
      build: () => DriverProfileBloc(
        drivers: _FakeDrivers(
          trialFailure: const ServerFailure(
            serverMessage: 'Pulsuz sınaq artıq istifadə olunub.',
          ),
        ),
      ),
      act: (bloc) => bloc.add(const DriverProTrialStarted()),
      expect: () => [
        isA<DriverProfileState>().having(
          (s) => s.proTrialStatus,
          'status',
          ActionStatus.inProgress,
        ),
        isA<DriverProfileState>()
            .having((s) => s.proTrialStatus, 'status', ActionStatus.failure)
            .having((s) => s.failure, 'failure', isNotNull)
            .having((s) => s.profile, 'profile', isNull),
      ],
    );
  });

  group('the PRO screen', () {
    testWidgets('an approved driver can start the trial from it', (
      tester,
    ) async {
      final drivers = _FakeDrivers(
        current: _profile(status: 'approved', pro: _offer),
      );
      await _pumpPro(tester, drivers);

      expect(find.text('30 gün pulsuz başla'), findsOneWidget);
      expect(find.textContaining('Ödəniş tələb olunmur'), findsOneWidget);
      expect(find.text('PRO aktivdir'), findsNothing);

      await tester.tap(find.text('30 gün pulsuz başla'));
      await tester.pumpAndSettle();

      expect(drivers.trialStarts, 1);
      expect(find.textContaining('PRO aktivdir'), findsOneWidget);
      expect(find.text('30 gün pulsuz başla'), findsNothing);
      expect(
        find.text('PRO aktivləşdi! Elanların artıq axtarışda birincidir.'),
        findsOneWidget,
      );
    });

    testWidgets('before approval it points to the documents instead', (
      tester,
    ) async {
      await _pumpPro(
        tester,
        _FakeDrivers(
          current: _profile(status: 'pending', pro: _offer),
        ),
      );

      expect(find.text('Sənədlərə keç'), findsOneWidget);
      expect(find.text('30 gün pulsuz başla'), findsNothing);
    });

    testWidgets('a spent trial says so and offers nothing to tap', (
      tester,
    ) async {
      await _pumpPro(
        tester,
        _FakeDrivers(
          current: _profile(
            status: 'approved',
            pro: {'active': false, 'trial_available': false, 'trial_days': 30},
          ),
        ),
      );

      expect(find.text('Pulsuz sınaq bitib'), findsOneWidget);
      expect(find.text('30 gün pulsuz başla'), findsNothing);
      expect(find.text('Sənədlərə keç'), findsNothing);
    });
  });

  group('ride cards', () {
    testWidgets('a PRO driver gets the badge next to their name', (
      tester,
    ) async {
      await _pumpCard(tester, _ride(isPro: true));
      expect(find.byType(ProBadge), findsOneWidget);
    });

    testWidgets('anyone else does not', (tester) async {
      await _pumpCard(tester, _ride(isPro: false));
      expect(find.byType(ProBadge), findsNothing);
    });

    testWidgets('the driver sees their own boosted listing marked', (
      tester,
    ) async {
      await _pumpCard(tester, _ride(isBoosted: true), showDriver: false);
      expect(find.text('Axtarışda önə çıxarılıb'), findsOneWidget);
    });

    testWidgets('a passenger is not shown the boost strip', (tester) async {
      await _pumpCard(tester, _ride(isBoosted: true, isPro: true));
      expect(find.text('Axtarışda önə çıxarılıb'), findsNothing);
    });
  });
}

const _offer = {'active': false, 'trial_available': true, 'trial_days': 30};

DriverProfile _profile({
  String status = 'approved',
  Map<String, Object?>? pro,
}) => DriverProfileModel.fromJson({
  'status': status,
  'instant_booking_default': false,
  'documents': <Object>[],
  'vehicle': null,
  'pro': ?pro,
});

dynamic _driver({bool? isPro}) => PublicUserModel.fromJson({
  'id': 7,
  'full_name': 'Aysel H.',
  'has_driver_profile': true,
  'is_pro': ?isPro,
});

dynamic _ride({bool isPro = false, bool isBoosted = false}) =>
    RideModel.fromJson({
      'id': 1,
      'driver': {
        'id': 42,
        'full_name': 'Rəşad M.',
        'has_driver_profile': true,
        'is_pro': isPro,
        'stats': {'driver_rating': 4.8, 'driver_review_count': 12},
      },
      'vehicle': {'id': 3, 'brand': 'Toyota', 'model': 'Prius', 'seats': 4},
      'from_city': {'id': 1, 'name': 'Bakı'},
      'to_city': {'id': 9, 'name': 'Qəbələ'},
      'departure_at': DateTime.now()
          .add(const Duration(days: 2))
          .toIso8601String(),
      'total_seats': 4,
      'booked_seats': 1,
      'seats_left': 3,
      'price_per_seat': 15.0,
      'status': 'active',
      'instant_booking': false,
      'is_boosted': isBoosted,
      'is_mine': false,
      'created_at': DateTime.now().toIso8601String(),
    });

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('az'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

Future<void> _pumpPro(WidgetTester tester, _FakeDrivers drivers) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final session = _MockSession();
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
      }),
    ),
  );
  final bloc = DriverProfileBloc(drivers: drivers)
    ..add(const DriverProfileRequested());
  addTearDown(bloc.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SessionBloc>.value(value: session),
        BlocProvider<DriverProfileBloc>.value(value: bloc),
      ],
      child: _app(const ProPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCard(
  WidgetTester tester,
  dynamic ride, {
  bool showDriver = true,
}) async {
  await tester.pumpWidget(
    _app(
      Scaffold(
        body: SingleChildScrollView(
          child: RideCard(ride: ride, showDriver: showDriver),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MockSession extends MockBloc<SessionEvent, SessionState>
    implements SessionBloc {}

/// The two calls the PRO flow makes; everything else is out of scope here.
class _FakeDrivers implements DriverRepository {
  _FakeDrivers({DriverProfile? current, this.trialFailure})
    : _current = current ?? _profile(pro: _offer);

  DriverProfile _current;
  final Failure? trialFailure;
  int trialStarts = 0;

  @override
  FutureResult<DriverProfile> profile() async => Ok(_current);

  @override
  FutureResult<DriverProfile> startProTrial() async {
    trialStarts++;
    final failure = trialFailure;
    if (failure != null) return Err(failure);
    _current = _profile(
      pro: {
        'active': true,
        'until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'trial_available': false,
        'trial_days': 30,
      },
    );
    return Ok(_current);
  }

  @override
  FutureResult<DriverProfile> setInstantBookingDefault(bool value) =>
      throw UnimplementedError();

  @override
  FutureResult<DriverProfile> uploadDocument({
    required DocumentType type,
    required UploadFile file,
    UploadFile? backFile,
  }) => throw UnimplementedError();

  @override
  FutureResult<List<Vehicle>> vehicles() => throw UnimplementedError();

  @override
  FutureResult<Vehicle> addVehicle(Vehicle vehicle) =>
      throw UnimplementedError();

  @override
  FutureResult<Vehicle> updateVehicle(Vehicle vehicle) =>
      throw UnimplementedError();

  @override
  FutureResult<void> deleteVehicle(int vehicleId) => throw UnimplementedError();
}
