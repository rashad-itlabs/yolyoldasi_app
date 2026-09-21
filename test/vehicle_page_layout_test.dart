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
import 'package:yolyoldasi/features/profile/data/repositories/driver_repository_impl.dart';
import 'package:yolyoldasi/features/profile/data/services/driver_api_service.dart';
import 'package:yolyoldasi/features/profile/data/services/vehicle_api_service.dart';
import 'package:yolyoldasi/features/profile/domain/repositories/driver_repository.dart';
import 'package:yolyoldasi/features/profile/presentation/pages/vehicle_page.dart';


/// The vehicle form has to survive a small screen and a large font.
///
/// It is the one form in the app with a row of side-by-side fields *and* a row
/// of colour swatches, which is exactly the combination that overflows first —
/// and it sits on the path to becoming a driver, so an overflow here is an
/// overflow in front of the people the marketplace is shortest of.
void main() {
  late _StubAdapter adapter;

  setUp(() => adapter = _StubAdapter());

  Widget wrap({double textScale = 1.0}) {
    final client = ApiClient(
      tokens: InMemoryTokenStorage(),
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://example.test/api/v1',
    );

    return RepositoryProvider<DriverRepository>(
      create: (_) => DriverRepositoryImpl(
        driver: DriverApiService(client),
        vehicles: VehicleApiService(client),
      ),
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
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: const VehiclePage(),
      ),
    );
  }

  /// A 320pt-wide phone — narrower than anything sold today, which is the
  /// point: if it fits here it fits everywhere.
  void narrowPhone(WidgetTester tester, {double width = 320, double height = 640}) {
    tester.view
      ..physicalSize = Size(width * 2, height * 2)
      ..devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('lays out on a narrow phone without overflowing', (tester) async {
    adapter.on('/vehicles', 200, {'data': const []});

    narrowPhone(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('survives the largest accessibility text scale', (tester) async {
    adapter.on('/vehicles', 200, {'data': const []});

    // 2.0 is roughly the top of the Android and iOS accessibility sliders.
    // Labels under the colour swatches are the first thing to give way.
    narrowPhone(tester);
    await tester.pumpWidget(wrap(textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out in landscape, where the form is shortest', (
    tester,
  ) async {
    adapter.on('/vehicles', 200, {'data': const []});

    narrowPhone(tester, width: 740, height: 360);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

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
