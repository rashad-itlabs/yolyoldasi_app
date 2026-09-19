import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/bloc/session/session_bloc.dart';
import '../features/cities/presentation/bloc/cities_bloc.dart';
import '../features/profile/presentation/bloc/driver_profile/driver_profile_bloc.dart';
import '../features/settings/presentation/bloc/settings/settings_bloc.dart';
import '../features/shell/presentation/bloc/badges/badges_bloc.dart';

/// The cross-cutting reactions that have no screen of their own.
///
/// Signing in has to do several things at once — read the driver profile, load
/// the badges, adopt the account's language — and none of them belong to a
/// page. Putting them here keeps every screen free of startup bookkeeping, and
/// keeps the order in one readable place.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.child});

  final Widget child;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Coming back from the background is the one moment the client knows its
    // data may be stale, and there is no push channel to tell it otherwise.
    final session = context.read<SessionBloc>();
    if (!session.state.isSignedIn) return;
    session.add(const SessionRefreshed());
    context.read<BadgesBloc>().add(const BadgesRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.user?.languageCode != current.user?.languageCode ||
          previous.user?.hasDriverProfile != current.user?.hasDriverProfile,
      listener: (context, state) {
        switch (state.status) {
          case SessionStatus.ready || SessionStatus.needsProfile:
            _onSignedIn(context, state);
          case SessionStatus.signedOut:
            context.read<BadgesBloc>().add(const BadgesCleared());
          case SessionStatus.booting || SessionStatus.blocked:
            break;
        }
      },
      child: widget.child,
    );
  }

  void _onSignedIn(BuildContext context, SessionState state) {
    // The city list is needed on almost every screen, so it is warmed here
    // rather than by whichever screen happens to open first.
    context.read<CitiesBloc>().add(const CitiesRequested());
    context.read<BadgesBloc>().add(const BadgesRefreshed());

    // `has_driver_profile` flips the moment a first vehicle is created, so the
    // profile is re-read whenever it changes rather than only at sign-in.
    context.read<DriverProfileBloc>().add(
      const DriverProfileRequested(force: true),
    );

    final languageCode = state.user?.languageCode;
    if (languageCode != null) {
      context.read<SettingsBloc>().add(SettingsLanguageSynced(languageCode));
    }
  }
}
