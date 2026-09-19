import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../rides/presentation/pages/my_rides_page.dart';
import '../../../rides/presentation/pages/search_home_page.dart';

/// First tab. Search for passengers, listings for drivers.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDriver = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.isDriverMode,
    );
    return isDriver ? const MyRidesPage() : const SearchHomePage();
  }
}
