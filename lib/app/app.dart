import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/di/app_dependencies.dart';
import '../core/localization/app_localizations.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/layout_size.dart';
import '../features/auth/presentation/bloc/phone_sign_in/phone_sign_in_bloc.dart';
import '../features/auth/presentation/bloc/session/session_bloc.dart';
import '../features/bookings/domain/repositories/booking_repository.dart';
import '../features/chat/domain/repositories/chat_repository.dart';
import '../features/cities/domain/repositories/city_repository.dart';
import '../features/cities/presentation/bloc/cities_bloc.dart';
import '../features/notifications/domain/repositories/notification_repository.dart';
import '../features/profile/domain/repositories/driver_repository.dart';
import '../features/profile/domain/repositories/user_repository.dart';
import '../features/profile/presentation/bloc/driver_profile/driver_profile_bloc.dart';
import '../features/reports/domain/repositories/report_repository.dart';
import '../features/reviews/domain/repositories/review_repository.dart';
import '../features/rides/domain/repositories/ride_repository.dart';
import '../features/rides/presentation/bloc/recent_searches/recent_searches_bloc.dart';
import '../features/rides/presentation/bloc/ride_search/ride_search_bloc.dart';
import '../features/settings/presentation/bloc/settings/settings_bloc.dart';
import '../features/shell/presentation/bloc/badges/badges_bloc.dart';
import 'app_startup.dart';

/// Root widget: repositories, the long-lived blocs, and the router.
///
/// Repositories are provided rather than passed down so a screen can build its
/// own short-lived bloc (`ChatBloc` for one thread, `RideDetailBloc` for one
/// ride) without every ancestor having to thread the dependency through.
class YolYoldasiApp extends StatelessWidget {
  const YolYoldasiApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<UserRepository>.value(value: dependencies.users),
        RepositoryProvider<DriverRepository>.value(value: dependencies.drivers),
        RepositoryProvider<CityRepository>.value(value: dependencies.cities),
        RepositoryProvider<RideRepository>.value(value: dependencies.rides),
        RepositoryProvider<BookingRepository>.value(
          value: dependencies.bookings,
        ),
        RepositoryProvider<ChatRepository>.value(value: dependencies.chat),
        RepositoryProvider<ReviewRepository>.value(value: dependencies.reviews),
        RepositoryProvider<NotificationRepository>.value(
          value: dependencies.notifications,
        ),
        RepositoryProvider<ReportRepository>.value(value: dependencies.reports),
        RepositoryProvider<AppDependencies>.value(value: dependencies),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SessionBloc>(
            create: (_) => SessionBloc(
              auth: dependencies.auth,
              users: dependencies.users,
              settings: dependencies.settings,
              // Read for its registration token at sign-out, so the device
              // stops receiving this account's notifications (API.md §5).
              push: dependencies.push,
            )..add(const SessionStarted()),
          ),
          BlocProvider<PhoneSignInBloc>(
            create: (_) => PhoneSignInBloc(auth: dependencies.auth),
          ),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(
              settings: dependencies.settings,
              users: dependencies.users,
            )..add(const SettingsStarted()),
          ),
          BlocProvider<CitiesBloc>(
            create: (_) =>
                CitiesBloc(cities: dependencies.cities)
                  ..add(const CitiesRequested()),
          ),
          BlocProvider<DriverProfileBloc>(
            create: (_) => DriverProfileBloc(drivers: dependencies.drivers),
          ),
          // The search form lives on the home tab and its results on a
          // top-level route, so the query they share is held above both.
          BlocProvider<RideSearchBloc>(
            create: (_) => RideSearchBloc(rides: dependencies.rides),
          ),
          BlocProvider<RecentSearchesBloc>(
            create: (_) => RecentSearchesBloc(rides: dependencies.rides),
          ),
          BlocProvider<BadgesBloc>(
            create: (_) => BadgesBloc(
              chat: dependencies.chat,
              notifications: dependencies.notifications,
            ),
          ),
        ],
        child: const AppStartup(child: _AppView()),
      ),
    );
  }
}

/// Holds the router, which has to outlive rebuilds — recreating it would reset
/// the navigation stack on every theme or locale change.
class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final GoRouter _router = buildRouter(context.read<SessionBloc>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final locale = settings.languageCode == null
        ? null
        : Locale(settings.languageCode!);

    return MaterialApp.router(
      title: 'Yol Yoldaşı',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,

      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supported) =>
          locale ?? AppLocalizations.resolve(deviceLocale, supported),

      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final layout = LayoutSize.fromShortestSide(
          mediaQuery.size.shortestSide,
        );

        // Clamp text scaling: beyond ~1.3 the dense ride cards start to break,
        // and the app already uses generous type sizes.
        final scaled = MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );

        if (layout.isCompact) return scaled;

        // A tablet is held at about the same distance as a phone, so phone-sized
        // type on a 13-inch screen reads as small. The theme is scaled rather
        // than the MediaQuery, which leaves the clamp above — and the reader's
        // own accessibility setting — to apply on top of it.
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            textTheme: theme.textTheme.apply(
              fontSizeFactor: layout.typeScale,
            ),
          ),
          child: scaled,
        );
      },
    );
  }
}
