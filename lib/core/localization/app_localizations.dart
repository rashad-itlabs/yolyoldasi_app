import 'package:flutter/widgets.dart';

import 'app_strings.dart';

export 'app_strings.dart';

/// Glue between Flutter's localization machinery and [AppStrings].
class AppLocalizations {
  const AppLocalizations(this.locale, this.strings);

  final Locale locale;
  final AppStrings strings;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('az'),
    Locale('ru'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppStrings of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    // Falls back to Azerbaijani so widget tests without a MaterialApp still work.
    return instance?.strings ?? AppStrings.of('az');
  }

  /// Picks the closest supported locale for a device locale.
  static Locale resolve(Locale? deviceLocale, Iterable<Locale> supported) {
    if (deviceLocale == null) return const Locale('az');
    for (final locale in supported) {
      if (locale.languageCode == deviceLocale.languageCode) return locale;
    }
    // Turkish speakers are served far better by Azerbaijani than by English.
    if (deviceLocale.languageCode == 'tr') return const Locale('az');
    return const Locale('az');
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale, AppStrings.of(locale.languageCode));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
