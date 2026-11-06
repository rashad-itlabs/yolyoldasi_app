import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/services/analytics.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/core/types.dart';
import 'package:yolyoldasi/core/utils/app_format.dart';
import 'package:yolyoldasi/features/cities/domain/entities/city.dart';
import 'package:yolyoldasi/features/profile/domain/entities/app_user.dart';
import 'package:yolyoldasi/features/rides/domain/entities/ride.dart';
import 'package:yolyoldasi/features/rides/presentation/widgets/ride_share_card.dart';
import 'package:yolyoldasi/features/rides/presentation/widgets/ride_share_sheet.dart';

/// The share sheet turns a ride into something that outlives the moment it was
/// made, so these pin down the parts that would quietly go wrong: a relative
/// date on a post, a picture of a ride that is gone, a card that changes with
/// the sender's settings.
void main() {
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  late List<MethodCall> shares;
  late Directory tempDir;
  late String? clipboard;
  late String shareReply;

  setUpAll(() async {
    for (final code in ['az', 'ru', 'en']) {
      await initializeDateFormatting(code);
    }
  });

  setUp(() {
    shares = [];
    clipboard = null;
    shareReply = 'dev.fluttercommunity.plus/share/success';
    tempDir = Directory.systemTemp.createTempSync('ride_share_test');

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shares.add(call);
      return shareReply;
    });
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => tempDir.path,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, null);
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    tempDir.deleteSync(recursive: true);
  });

  /// Tomorrow, so a relative label would read "Sabah" if one slipped through.
  DateTime tomorrowMorning() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 9);
  }

  Ride ride({
    DateTime? departureAt,
    RideStatus status = RideStatus.active,
    City from = const City(id: 1, name: 'Bakı'),
    City to = const City(id: 2, name: 'Gəncə'),
  }) => Ride(
    id: 7,
    driver: const PublicUser(id: 3, fullName: 'Rəşad Əliyev'),
    fromCity: from,
    toCity: to,
    departureAt: departureAt ?? tomorrowMorning(),
    totalSeats: 4,
    bookedSeats: 1,
    seatsLeft: 3,
    pricePerSeat: 15,
    status: status,
    createdAt: DateTime(2026),
    shareUrl: 'https://yolyoldasi.az/r/7',
  );

  Widget app(
    Widget home, {
    String locale = 'az',
    _RecordingAnalytics? analytics,
    double textScale = 1,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return RepositoryProvider<Analytics>.value(
      value: analytics ?? _RecordingAnalytics(),
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: home),
      ),
    );
  }

  /// The string tables load asynchronously, so the first frame is empty.
  Future<void> mount(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  /// A page with the real entry point behind one button.
  Widget launcher(Ride ride) => Center(
    child: Builder(
      builder: (button) => TextButton(
        onPressed: () => RideShareSheet.show(button, ride),
        child: const Text('share'),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
  }

  /// Rendering and writing the file are real async work, which the fake clock
  /// of a widget test will not wait for.
  Future<void> tapAndWaitForShare(WidgetTester tester, Finder button) async {
    await tester.runAsync(() async {
      await tester.tap(button);
      for (var i = 0; i < 200 && shares.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  group('AppFormat.dayMonthWithTime', () {
    test('stays a date when the ride leaves tomorrow', () {
      final strings = AppStrings.of('az');
      final fmt = AppFormat(strings);

      final label = fmt.dayMonthWithTime(tomorrowMorning());

      expect(label, isNot(contains(strings.tomorrow)));
      expect(label, endsWith('09:00'));
      expect(label, startsWith(fmt.dayMonth(tomorrowMorning())));
    });
  });

  group('RideShareCard', () {
    testWidgets('shows an absolute date and a readable address', (
      tester,
    ) async {
      await mount(tester, app(RideShareCard(ride: ride())));

      final strings = AppStrings.of('az');
      final fmt = AppFormat(strings);
      expect(
        find.text(fmt.dayMonthWithTime(tomorrowMorning())),
        findsOneWidget,
      );
      expect(find.textContaining(strings.tomorrow), findsNothing);
      expect(find.text('yolyoldasi.az/r/7'), findsOneWidget);
    });

    testWidgets('names the cities in the viewer\'s language', (tester) async {
      await mount(tester, app(RideShareCard(ride: ride()), locale: 'ru'));

      expect(find.text('Баку'), findsOneWidget);
      expect(find.text('Bakı'), findsNothing);
    });

    testWidgets('shows the women-only condition', (tester) async {
      await mount(tester, app(RideShareCard(ride: _womenOnly(ride()))));

      expect(find.text(AppStrings.of('az').womenOnlyRide), findsOneWidget);
    });

    testWidgets('leaves out who is driving', (tester) async {
      await mount(tester, app(RideShareCard(ride: ride())));

      expect(find.textContaining('Rəşad'), findsNothing);
    });

    testWidgets('does not overflow, whatever the name or the text scale', (
      tester,
    ) async {
      const unknown = City(
        id: 99,
        name: 'Çox uzun adı olan və cədvəldə olmayan bir şəhər',
      );

      for (final code in ['az', 'ru', 'en']) {
        await mount(
          tester,
          app(
            RideShareCard(
              ride: _womenOnly(ride(from: unknown, to: unknown)),
            ),
            locale: code,
            textScale: 3,
          ),
        );
        expect(tester.takeException(), isNull, reason: code);
      }
    });

    testWidgets('looks the same to a sender in dark mode', (tester) async {
      await mount(
        tester,
        app(RideShareCard(ride: ride()), themeMode: ThemeMode.dark),
      );

      final context = tester.element(find.text('Bakı'));
      expect(Theme.of(context).brightness, Brightness.light);
    });
  });

  group('RideShareSheet', () {
    testWidgets('fits on a small phone with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await mount(tester, app(launcher(ride()), textScale: 1.3));
      await openSheet(tester);

      expect(tester.takeException(), isNull);
      final strings = AppStrings.of('az');
      expect(find.text(strings.shareAsImage).hitTestable(), findsOneWidget);
      expect(find.text(strings.shareAsLink).hitTestable(), findsOneWidget);
    });

    testWidgets('sends a 1080×1350 image and copies the caption', (
      tester,
    ) async {
      final analytics = _RecordingAnalytics();
      final strings = AppStrings.of('az');
      final fmt = AppFormat(strings);

      await mount(tester, app(launcher(ride()), analytics: analytics));
      await openSheet(tester);
      await tapAndWaitForShare(tester, find.text(strings.shareAsImage));

      expect(shares, hasLength(1));
      final args = shares.single.arguments as Map;
      expect(args['text'], isNull);
      expect(args['mimeTypes'], ['image/png']);

      final path = (args['paths'] as List).single as String;
      expect(path, endsWith('yol-yoldasi-7.png'));
      final size = _pngSize(File(path).readAsBytesSync());
      expect(size, const Size(1080, 1350));

      expect(clipboard, contains('Bakı → Gəncə'));
      expect(clipboard, contains(fmt.dayMonthWithTime(tomorrowMorning())));
      expect(clipboard, isNot(contains(strings.tomorrow)));
      expect(clipboard, contains('https://yolyoldasi.az/r/7'));

      expect(analytics.params.single['format'], 'image');
      expect(analytics.params.single['ride_id'], 7);

      // Done, so the sheet is gone.
      expect(find.byType(RideShareSheet), findsNothing);
    });

    testWidgets('sends the link as text and leaves the clipboard alone', (
      tester,
    ) async {
      final analytics = _RecordingAnalytics();
      final strings = AppStrings.of('az');

      await mount(tester, app(launcher(ride()), analytics: analytics));
      await openSheet(tester);
      await tapAndWaitForShare(tester, find.text(strings.shareAsLink));

      final args = shares.single.arguments as Map;
      expect(args['paths'], isNull);
      expect(args['text'], contains('https://yolyoldasi.az/r/7'));
      expect(args['text'], contains(strings.tomorrow));
      expect(clipboard, isNull);
      expect(analytics.params.single['format'], 'link');
    });

    testWidgets('gives the platform a real on-screen anchor for the iPad', (
      tester,
    ) async {
      final strings = AppStrings.of('az');

      await mount(tester, app(launcher(ride())));
      await openSheet(tester);
      final expected = tester.getRect(find.byType(FittedBox).first);
      await tapAndWaitForShare(tester, find.text(strings.shareAsLink));

      final args = shares.single.arguments as Map;
      final origin = Rect.fromLTWH(
        args['originX'] as double,
        args['originY'] as double,
        args['originWidth'] as double,
        args['originHeight'] as double,
      );
      expect(origin.isEmpty, isFalse);
      expect(origin.left, closeTo(expected.left, 1));
      expect(origin.top, closeTo(expected.top, 1));
      expect(origin.width, closeTo(expected.width, 1));
      expect(origin.height, closeTo(expected.height, 1));
    });

    testWidgets('stays open when the user backs out of the picker', (
      tester,
    ) async {
      shareReply = ''; // What both platforms send for a dismissed picker.
      final strings = AppStrings.of('az');

      await mount(tester, app(launcher(ride())));
      await openSheet(tester);
      await tapAndWaitForShare(tester, find.text(strings.shareAsLink));

      expect(find.byType(RideShareSheet), findsOneWidget);
      // And the buttons work again.
      final button = tester.widget<TextButton>(find.byType(TextButton).first);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a cancelled ride goes straight out as a link', (tester) async {
      await mount(tester, app(launcher(ride(status: RideStatus.cancelled))));
      await tapAndWaitForShare(tester, find.text('share'));

      expect(find.byType(RideShareSheet), findsNothing);
      final args = shares.single.arguments as Map;
      expect(args['paths'], isNull);
      expect(args['text'], contains('https://yolyoldasi.az/r/7'));
    });

    testWidgets('a ride that already left goes straight out as a link', (
      tester,
    ) async {
      final past = DateTime.now().subtract(const Duration(days: 1));

      await mount(tester, app(launcher(ride(departureAt: past))));
      await tapAndWaitForShare(tester, find.text('share'));

      expect(find.byType(RideShareSheet), findsNothing);
      expect((shares.single.arguments as Map)['paths'], isNull);
    });

    testWidgets('reports a platform failure on the page', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
            shares.add(call);
            throw PlatformException(code: 'error');
          });
      final strings = AppStrings.of('az');

      await mount(tester, app(launcher(ride())));
      await openSheet(tester);
      await tapAndWaitForShare(tester, find.text(strings.shareAsLink));

      expect(find.byType(RideShareSheet), findsNothing);
      expect(find.text(strings.shareFailed), findsOneWidget);
    });
  });
}

Ride _womenOnly(Ride ride) => ride.copyWith(womenOnly: true);

/// Reads the size straight out of the IHDR chunk, which is what the receiving
/// app will see.
Size _pngSize(Uint8List bytes) {
  final header = ByteData.sublistView(bytes);
  return Size(header.getUint32(16).toDouble(), header.getUint32(20).toDouble());
}

class _RecordingAnalytics implements Analytics {
  final List<Json> params = [];

  @override
  void log(String name, {Json? params}) {
    if (name == Ev.rideShared) this.params.add(params!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
