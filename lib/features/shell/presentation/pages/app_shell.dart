import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../app_update/presentation/widgets/optional_update_gate.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../bloc/badges/badges_bloc.dart';

/// Bottom-navigation host for the four main tabs.
///
/// The same four branches serve both modes; only the labels and icons change,
/// which keeps navigation state intact when the user flips between driver and
/// passenger.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The soft update prompt, if one is owed. Here rather than in
      // `AppStartup` because a modal sheet needs a Navigator above it, and
      // this is the first screen worth interrupting anyway.
      body: OptionalUpdateGate(child: navigationShell),
      // Four destinations spread across a 13-inch screen end up so far apart
      // that the bar stops reading as one control, so they are held to the
      // same column width as the content above them.
      //
      // The surface still spans the screen: a bar that stops short of the
      // edges reads as a floating panel, and on iOS it would leave the home
      // indicator sitting on the page background rather than on the bar.
      // Same colour the NavigationBar paints itself (app_theme.dart:338), so
      // the strip beside it reads as the same surface rather than as page
      // background showing through.
      bottomNavigationBar: ColoredBox(
        color: context.palette.surfaceElevated,
        child: Align(
          // `heightFactor: 1` is load-bearing: without it the Align takes every
          // pixel of height the Scaffold offers, the bar floats in the middle
          // of the screen and the body is squeezed to nothing.
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: _NavigationBar(navigationShell: navigationShell),
          ),
        ),
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDriver = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.isDriverMode,
    );
    // A signed-out visitor is allowed to browse (API.md §18), so the shell is
    // on screen without an account. The other three tabs have nothing to show
    // them — they are all `/me`-shaped — so tapping one is read as "I want in".
    final isGuest = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.user == null,
    );
    final badges = context.watch<BadgesBloc>().state;

    return NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) {
        if (isGuest && index != 0) {
          context.push(Routes.login);
          return;
        }

        navigationShell.goBranch(
          index,
          // Tapping the active tab pops it back to its root.
          initialLocation: index == navigationShell.currentIndex,
        );
        // The counts have no push channel yet (API.md §13), so moving
        // between tabs is the app's best cue to re-read them.
        context.read<BadgesBloc>().add(const BadgesRefreshed());
      },
      destinations: [
        NavigationDestination(
          icon: Icon(
            isDriver ? Icons.directions_car_outlined : Icons.search_rounded,
          ),
          selectedIcon: Icon(
            isDriver ? Icons.directions_car_filled : Icons.search_rounded,
          ),
          label: isDriver ? l10n.navRides : l10n.navSearch,
        ),
        NavigationDestination(
          icon: const Icon(Icons.confirmation_number_outlined),
          selectedIcon: const Icon(Icons.confirmation_number),
          label: isDriver ? l10n.navRequests : l10n.navBookings,
        ),
        NavigationDestination(
          icon: _Badged(
            label: badges.messageBadge,
            child: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          selectedIcon: _Badged(
            label: badges.messageBadge,
            child: const Icon(Icons.chat_bubble_rounded),
          ),
          label: l10n.navChat,
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(Icons.person_rounded),
          label: l10n.navProfile,
        ),
      ],
    );
  }
}

/// A tab icon with an optional count pill. [label] is already capped at "99+"
/// by [BadgesState], so the pill never has to grow.
class _Badged extends StatelessWidget {
  const _Badged({required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) return child;
    return Badge(label: Text(label!), child: child);
  }
}
