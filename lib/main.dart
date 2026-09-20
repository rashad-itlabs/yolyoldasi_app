import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/di/app_dependencies.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/layout_size.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) Bloc.observer = const AppBlocObserver();

  // Portrait only on phones: every screen is a single column and the ride cards
  // are tuned for phone widths, so landscape buys nothing and costs the
  // vertical room the forms need.
  //
  // Tablets rotate freely. A locked-portrait app on an iPad is the one that
  // refuses to turn when the user does, and a 13-inch screen has room for the
  // column either way. Read from the platform view because MediaQuery does not
  // exist yet — this runs before the first frame.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortestSide =
      view.physicalSize.shortestSide / view.devicePixelRatio;

  if (LayoutSize.fromShortestSide(shortestSide).isCompact) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Month and weekday names for all three languages.
  for (final locale in AppLocalizations.supportedLocales) {
    await initializeDateFormatting(locale.languageCode);
  }

  final preferences = await SharedPreferences.getInstance();

  // Builds the object graph, restores the stored Sanctum token and loads the
  // device preferences, all before the first frame — so the app never flashes
  // the sign-in screen at a user who is already signed in.
  final dependencies = await AppDependencies.bootstrap(
    preferences: preferences,
  );

  runApp(YolYoldasiApp(dependencies: dependencies));
}
