import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/core/widgets/otp_input.dart';
import 'package:yolyoldasi/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yolyoldasi/features/auth/data/services/auth_api_service.dart';
import 'package:yolyoldasi/features/auth/presentation/bloc/phone_sign_in/phone_sign_in_bloc.dart';
import 'package:yolyoldasi/features/auth/presentation/pages/login_page.dart';
import 'package:yolyoldasi/features/profile/data/services/device_token_api_service.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';

/// The sign-in screen: the mode picker, the number, and the move to the code
/// step once `POST /auth/phone/request` has answered.
void main() {
  late _StubAdapter adapter;

  setUp(() => adapter = _StubAdapter());

  /// Built inside each test rather than in `setUp`: a bloc created outside the
  /// tester's async zone keeps its stream there too, and no amount of `pump`
  /// then delivers its states to the screen.
  PhoneSignInBloc buildBloc() {
    final tokens = InMemoryTokenStorage();
    final client = ApiClient(
      tokens: tokens,
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://example.test/api/v1',
    );
    final bloc = PhoneSignInBloc(
      auth: AuthRepositoryImpl(
        api: AuthApiService(client),
        deviceTokens: DeviceTokenApiService(client),
        tokens: tokens,
        unauthorized: client.onUnauthorized,
      ),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  Widget wrap(PhoneSignInBloc bloc) => BlocProvider<PhoneSignInBloc>.value(
    value: bloc,
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
      home: const LoginPage(),
    ),
  );

  /// The screen is a lazy [ListView]; on the default 800×600 surface the widgets
  /// below the fold are never built, and `findsNothing` would pass for the
  /// wrong reason.
  void tallWindow(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1200, 4200)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('offers both sides of the app, passenger first', (tester) async {
    tallWindow(tester);
    final bloc = buildBloc();
    await tester.pumpWidget(wrap(bloc));
    await tester.pump();

    expect(find.text('Necə davam edirsən?'), findsOneWidget);
    expect(find.text('Sərnişin rejimi'), findsOneWidget);
    expect(find.text('Sürücü rejimi'), findsOneWidget);
    expect(bloc.state.mode, UserMode.passenger);
  });

  testWidgets('picking driver says what it needs up front', (tester) async {
    tallWindow(tester);
    final bloc = buildBloc();
    await tester.pumpWidget(wrap(bloc));
    await tester.pump();

    // Nothing is said until it is relevant.
    expect(find.textContaining('avtomobil lazımdır'), findsNothing);

    await tester.tap(find.text('Sürücü rejimi'));
    await tester.pumpAndSettle();

    expect(bloc.state.mode, UserMode.driver);
    // `PUT /me/mode` refuses driver without a car, and that cannot be known
    // before `/me` answers — so the screen warns rather than failing later.
    expect(find.textContaining('avtomobil lazımdır'), findsOneWidget);
  });

  testWidgets('the pick survives typing the number', (tester) async {
    tallWindow(tester);
    final bloc = buildBloc();
    await tester.pumpWidget(wrap(bloc));
    await tester.pump();

    await tester.tap(find.text('Sürücü rejimi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '0505550001');
    await tester.pumpAndSettle();

    expect(bloc.state.mode, UserMode.driver);
    // Grouped as typed, and the leading 0 belongs to the country code rather
    // than the national number.
    expect(bloc.state.phone, '50 555 00 01');
  });

  testWidgets('an incomplete number cannot ask for a code', (tester) async {
    tallWindow(tester);
    final bloc = buildBloc();
    await tester.pumpWidget(wrap(bloc));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '505');
    await tester.pumpAndSettle();
    expect(bloc.state.canRequestCode, isFalse);

    await tester.enterText(find.byType(TextField).first, '0505550001');
    await tester.pumpAndSettle();
    expect(bloc.state.canRequestCode, isTrue);
  });

  testWidgets('an issued code moves the screen to the boxes', (tester) async {
    tallWindow(tester);
    adapter.on('/auth/phone/request', 200, {
      'message': 'Təsdiq kodu yaradıldı.',
      'phone': '+994505550001',
      'expires_in': 300,
      'resend_after': 60,
    });
    final bloc = buildBloc();
    await tester.pumpWidget(wrap(bloc));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '0505550001');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kod göndər'));
    await tester.pumpAndSettle();

    expect(bloc.state.step, PhoneSignInStep.code);
    expect(find.byType(OtpInput), findsOneWidget);
    // The number is shown back in the form the server settled on.
    expect(find.textContaining('+994 50 555 00 01'), findsOneWidget);
    // 60 seconds to wait, so the resend button is a countdown rather than a
    // live button that would only earn a 429.
    expect(find.text('Kodu yenidən göndər'), findsNothing);
    expect(find.textContaining('01:00'), findsOneWidget);

    // Run the wait out: the countdown stops itself at zero and hands the
    // button back. It also leaves no armed timer for the binding to trip on.
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(bloc.state.resendIn, 0);
    expect(find.text('Kodu yenidən göndər'), findsOneWidget);
  });

  testWidgets('the code the API echoes back is offered, not hidden', (
    tester,
  ) async {
    tallWindow(tester);
    adapter.on('/auth/phone/request', 200, {
      'phone': '+994505550001',
      'expires_in': 300,
      'resend_after': 60,
      // Sent only while no SMS provider is wired up — without it nobody can
      // sign in on a device that receives no SMS.
      'code': '752082',
    });
    final bloc = buildBloc();
    await tester.pumpWidget(wrap(bloc));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '0505550001');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kod göndər'));
    await tester.pumpAndSettle();

    expect(find.text('SMS hələ qoşulmayıb'), findsOneWidget);
    expect(find.text('752082'), findsOneWidget);

    // Drains the resend countdown so no timer is left armed at teardown.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('changing the number goes back with it intact', (tester) async {
    tallWindow(tester);
    adapter.on('/auth/phone/request', 200, {
      'phone': '+994505550001',
      'expires_in': 300,
      'resend_after': 60,
    });
    final bloc = buildBloc();
    await tester.pumpWidget(wrap(bloc));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '0505550001');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kod göndər'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nömrəni dəyiş'));
    await tester.pumpAndSettle();

    expect(bloc.state.step, PhoneSignInStep.phone);
    // Retyping a number the user only wanted to correct would be a poor trade.
    expect(bloc.state.phone, '50 555 00 01');
    expect(bloc.state.challenge, isNull);
  });
}

/// Dio adapter that answers by path. An unscripted path answers 404, which is
/// what keeps "nothing reaches the network" honest.
class _StubAdapter implements HttpClientAdapter {
  final List<({String path, int status, Object? body})> _rules = [];

  void on(String path, int status, Object? body) =>
      _rules.add((path: path, status: status, body: body));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final rule = _rules.where((r) => options.path.endsWith(r.path)).lastOrNull;
    return ResponseBody.fromString(
      jsonEncode(rule?.body ?? {'message': 'not scripted'}),
      rule?.status ?? 404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
