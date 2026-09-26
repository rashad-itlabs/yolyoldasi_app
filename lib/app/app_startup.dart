import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/app_dependencies.dart';
import '../core/extensions/context_extensions.dart';
import '../core/services/analytics.dart';
import '../core/services/push/foreground_message_watcher.dart';
import '../core/services/push/local_notifications.dart';
import '../core/services/push/pending_deep_link.dart';
import '../core/services/push/push_message.dart';
import '../core/services/push/push_service.dart';
import '../core/widgets/app_feedback.dart';
import '../features/app_update/presentation/bloc/app_update/app_update_bloc.dart';
import '../features/auth/presentation/bloc/session/session_bloc.dart';
import '../features/cities/presentation/bloc/cities_bloc.dart';
import '../features/profile/domain/entities/user_enums.dart';
import '../features/profile/domain/repositories/user_repository.dart';
import '../features/profile/presentation/bloc/driver_profile/driver_profile_bloc.dart';
import '../features/settings/presentation/bloc/settings/settings_bloc.dart';
import '../features/shell/presentation/bloc/badges/badges_bloc.dart';

/// The cross-cutting reactions that have no screen of their own.
///
/// Signing in has to do several things at once — read the driver profile, load
/// the badges, adopt the account's language, register for push — and none of
/// them belong to a page. Putting them here keeps every screen free of startup
/// bookkeeping, and keeps the order in one readable place.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.child});

  final Widget child;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> with WidgetsBindingObserver {
  late final AppDependencies _dependencies;
  late final PushService _push;
  late final LocalNotifications _notifications;
  late final PendingDeepLink _pending;
  late final ForegroundMessageWatcher _watcher;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushMessage>? _tapSubscription;
  StreamSubscription<PushMessage>? _foregroundSubscription;
  StreamSubscription<PushMessage>? _watcherSubscription;

  /// Set once the channels exist and permission has been settled, so a second
  /// sign-in on the same launch does not prompt again.
  bool _pushStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _dependencies = context.read<AppDependencies>();
    _push = _dependencies.push;
    _notifications = _dependencies.localNotifications;
    _pending = _dependencies.pendingDeepLink;
    _watcher = _dependencies.foregroundMessages;

    // A tap on a notification this app drew itself, rather than one the OS
    // drew. Both routes end in the same place.
    _notifications.onTap = _onPushTapped;

    _tapSubscription = _push.taps.listen(_onPushTapped);

    // Two sources, one handler: a message the transport delivered, and a
    // message the watcher noticed by asking. They render identically, so the
    // user cannot tell which one found it — and when a transport is wired,
    // nothing downstream changes.
    _foregroundSubscription = _push.foregroundMessages.listen(_onForeground);
    _watcherSubscription = _watcher.messages.listen(_onForeground);

    // Rotation is not an edge case: a restore, a reinstall or a data clear all
    // mint a new token, and the server keeps sending to the old one until it
    // is told otherwise.
    _tokenSubscription = _push.tokenChanges.listen(_registerToken);

    // The first event of every session, and the denominator of every funnel
    // number that follows it.
    _dependencies.analytics.log(Ev.appOpen);
  }

  @override
  void dispose() {
    _notifications.onTap = null;
    _tokenSubscription?.cancel();
    _tapSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _watcherSubscription?.cancel();
    _watcher.pause();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      // Off screen, Dart stops running anyway — but leaving the timer armed
      // would fire a burst of catch-up requests the moment the app returns.
      // The baseline is kept, so returning does not replay what arrived while
      // away; that backlog belongs to the push transport.
      _watcher.pause();

      // Last chance to get the buffer out. A session that ends here — the user
      // swipes the app away and never returns — would otherwise lose
      // everything it recorded, and those are exactly the sessions worth
      // understanding.
      unawaited(_dependencies.analytics.flush());
      return;
    }

    // Ahead of everything below, and outside the signed-in check that guards
    // it: a release can be withdrawn while the app sits in the background,
    // and an app left open for a week would otherwise never hear about it.
    // One small request per resume.
    context.read<AppUpdateBloc>().add(const AppUpdateChecked());

    final session = context.read<SessionBloc>();

    // Coming back from the background is when the client knows its data may be
    // stale. It is also the only recovery path for a device that was
    // force-stopped, where no push can arrive at all until the user returns.
    if (!session.state.isSignedIn) return;
    session.add(const SessionRefreshed());
    context.read<BadgesBloc>().add(const BadgesRefreshed());

    // Publishing waits on an admin approving the documents, which happens
    // while the app is closed. Without this the driver would come back to a
    // locked publish button until the next sign-in.
    context.read<DriverProfileBloc>().add(
      const DriverProfileRequested(force: true),
    );

    // Re-settling push on resume is how the app notices permission that was
    // granted *outside* it. A user who refuses the prompt, then turns
    // notifications on weeks later in the OS settings, never signs in again —
    // so without this the transport would stay written off as unusable and the
    // poller would go on announcing every message a second time. Repeating it
    // is cheap: the prompt is shown once, and asking for permission that is
    // already granted only reports the current answer.
    //
    // It also restarts or stops the watcher, which is why nothing else here
    // touches it.
    unawaited(_startPush(session.state));
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
            // The token is released by SessionBloc; this clears what is already
            // on screen, so the next account never inherits the previous one's
            // tray.
            _pending.clear();
            _watcher.stop();
            unawaited(_notifications.cancelAll());
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

    unawaited(_startPush(state));

    // A tap that cold-started the app has been waiting for exactly this: the
    // router rewrites every location to /splash while the session is booting,
    // so navigating any earlier would land the user on the splash screen.
    if (state.status == SessionStatus.ready) _drainPendingLink();
  }

  /// Creates the channels, settles permission, names the account to the
  /// transport, and registers the subscription.
  ///
  /// Ordered deliberately. The channels exist before anything can be posted to
  /// them; permission is settled before a subscription is asked for, because on
  /// iOS APNs issues none without it; `identify` runs next, because it is what
  /// makes the account addressable at all; and only then does the subscription
  /// id reach the API, so the server never holds an id for a device that cannot
  /// show anything.
  ///
  /// [identify] is the one step that runs even when permission was refused.
  /// The alias is free to record and costs nothing if it is never used, and it
  /// means a user who turns notifications on months later in the OS settings is
  /// reachable immediately, with no further sign-in.
  Future<void> _startPush(SessionState state) async {
    if (!_pushStarted) {
      _pushStarted = true;
      if (!mounted) return;
      await _notifications.initialize(context.l10n);
      await _notifications.requestPermission();
    }

    final granted = await _push.start();

    final user = state.user;
    if (user != null) {
      await _push.identify(
        externalId: user.id.toString(),
        languageCode: user.languageCode,
      );
    }

    // Polling is the consolation prize, not a supplement: with a working
    // transport it would announce every message a second time. This is the
    // only place the choice is made, and it is remade on every resume, so
    // permission granted outside the app is picked up without a sign-in.
    final userId = user?.id;
    if (granted) {
      _watcher.stop();
    } else if (userId != null) {
      _watcher.start(userId: userId);
    }

    if (!granted) return;

    final token = _push.currentToken;
    if (token != null) await _registerToken(token);
  }

  /// `POST /me/device-tokens` — API.md §5 does `updateOrCreate`, so re-sending
  /// the same id on every launch is both safe and the documented usage.
  ///
  /// `external_id` travels with it so the server can record which account this
  /// device is addressable as, and fall back to the subscription id only when
  /// the alias route fails.
  Future<void> _registerToken(String token) async {
    if (!mounted) return;
    final userId = context.read<SessionBloc>().state.userId;
    final users = context.read<UserRepository>();
    await users.registerDeviceToken(
      token: token,
      platform: DevicePlatform.current,
      provider: _push.provider,
      externalId: userId?.toString(),
    );
  }

  /// A push that arrived while the app was on screen.
  ///
  /// FCM draws nothing on Android while the app is foreground, and iOS needs
  /// telling — so this is the one state where the notification is the app's own
  /// responsibility.
  void _onForeground(PushMessage message) {
    if (!mounted) return;

    // Re-read, not adjusted. The push stands for rows the server committed
    // before sending it, so the count already includes them — and a chat push
    // stands for two, the message and its notification row, so both counters
    // move. This used to set the counter to 1 while meaning "one more", which
    // is why the bell reset instead of rising.
    //
    // Before the open-thread check, not after: if the user leaves the thread
    // before its next poll marks the message read, nothing else would re-read
    // the badges and both would stay one short. While they stay, the poll's
    // read (`ChatRepository.threadsRead`) lowers them again within a tick.
    context.read<BadgesBloc>().add(const BadgesRefreshed());

    // Already reading that thread: the message is about to appear in the list
    // on its own, so a banner over it would be noise. Only `newMessage`
    // carries a conversation id, so no other banner is swallowed here.
    if (_pending.isOpen(message.conversationId)) return;

    // The server's wording is in whatever language it guessed. The app has the
    // same lines in az/ru/en and knows which one this user reads, so the type
    // line is localized here and only free text is taken from the push.
    final typeLine = context.l10n.byKey(message.type.titleKey);
    final title = message.title ?? message.actorName ?? typeLine;

    // Never the same string twice: with no body and no sender, the type line is
    // the title and the body stays empty.
    final body = message.body ?? (message.actorName == null ? '' : typeLine);

    unawaited(_notifications.show(message, title: title, body: body));
  }

  void _onPushTapped(PushMessage message) {
    _pending.offer(message);

    if (!mounted) return;
    final session = context.read<SessionBloc>();

    // A tap on a locked or booting app waits; there is nowhere to land yet.
    if (session.state.status != SessionStatus.ready) return;
    _drainPendingLink();
  }

  void _drainPendingLink() {
    final message = _pending.take();
    if (message == null) return;
    if (!mounted) return;

    // Opening the thread means the tray entry for it is stale.
    unawaited(_notifications.cancelFor(message));

    final route = PendingDeepLink.routeFor(message);
    if (route == null) {
      // API.md §13: every id can be null at once when the subject has been
      // deleted. Saying so beats opening a blank screen.
      AppFeedback.error(context, context.l10n.linkUnavailableBody);
      return;
    }

    context.push(route);
    context.read<BadgesBloc>().add(const BadgesRefreshed());
  }
}
