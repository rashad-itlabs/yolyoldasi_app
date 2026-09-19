import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
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
    final l10n = context.l10n;
    final isDriver = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.isDriverMode,
    );
    final badges = context.watch<BadgesBloc>().state;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
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
      ),
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
