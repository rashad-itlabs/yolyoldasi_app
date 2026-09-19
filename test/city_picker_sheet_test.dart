import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/localization/app_localizations.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/features/cities/domain/entities/city.dart';
import 'package:yolyoldasi/features/cities/domain/repositories/city_repository.dart';
import 'package:yolyoldasi/features/cities/presentation/bloc/cities_bloc.dart';
import 'package:yolyoldasi/features/rides/presentation/widgets/city_picker_sheet.dart';

/// The picker once read `context.l10n` from `initState`, which throws
/// "dependOnInheritedWidgetOfExactType<_LocalizationsScope>() ... was called
/// before _CityPickerSheetState.initState() completed" and took down the whole
/// publish flow. Localization-dependent setup belongs in
/// `didChangeDependencies`.
void main() {
  const cities = [
    City(id: 1, name: 'Bakı'),
    City(id: 9, name: 'Qəbələ'),
    City(id: 2, name: 'Gəncə'),
  ];

  Widget wrap(Widget child) {
    return BlocProvider<CitiesBloc>(
      create: (_) =>
          CitiesBloc(cities: _FakeCityRepository(cities))
            ..add(const CitiesRequested()),
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
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('opens without touching Localizations during initState', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const CityPickerSheet(title: 'Haradan')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bakı'), findsOneWidget);
  });

  testWidgets('filters as the user types', (tester) async {
    await tester.pumpWidget(wrap(const CityPickerSheet(title: 'Haradan')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'qeb');
    await tester.pumpAndSettle();

    // Diacritic-insensitive: "qeb" has to find "Qəbələ".
    expect(find.text('Qəbələ'), findsOneWidget);
    expect(find.text('Bakı'), findsNothing);
  });

  testWidgets('a stale query from a previous opening is cleared', (
    tester,
  ) async {
    // The bloc outlives the sheet, so its query survives a close. Reopening
    // with an empty field must not show yesterday's filtered list.
    final bloc = CitiesBloc(cities: _FakeCityRepository(cities))
      ..add(const CitiesRequested());
    addTearDown(bloc.close);

    Widget sheet() => BlocProvider<CitiesBloc>.value(
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
        home: const Scaffold(body: CityPickerSheet(title: 'Haradan')),
      ),
    );

    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'qeb');
    await tester.pumpAndSettle();
    expect(find.text('Bakı'), findsNothing);

    // Close and reopen.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();

    expect(find.text('Bakı'), findsOneWidget);
  });
}

class _FakeCityRepository implements CityRepository {
  _FakeCityRepository(this._cities);

  final List<City> _cities;

  @override
  FutureResult<List<City>> all() async => Ok(_cities);

  @override
  City? byId(int? id) => _cities.where((c) => c.id == id).firstOrNull;

  @override
  List<City>? search(String query, String languageCode) => _cities;

  @override
  void invalidate() {}
}
