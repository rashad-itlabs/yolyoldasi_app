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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) Bloc.observer = const AppBlocObserver();

  // Portrait only: every screen is a single column and the ride cards are
  // tuned for phone widths.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
