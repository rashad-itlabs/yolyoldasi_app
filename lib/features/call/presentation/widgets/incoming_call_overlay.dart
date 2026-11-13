import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/call_bloc.dart';
import '../incoming/incoming_calls.dart';
import '../pages/call_page.dart';

/// Shows an answered call's screen over the whole app.
///
/// An overlay rather than a route because an answered call does not wait for
/// the app: it may have been picked up on the lock screen of an app that was
/// not running, while the router still pins every location to the splash
/// screen. Laid over [child], it is there the moment the app is opened, and
/// [child] keeps its place in the tree underneath.
class IncomingCallOverlay extends StatelessWidget {
  const IncomingCallOverlay({
    super.key,
    required this.calls,
    required this.child,
  });

  final IncomingCalls calls;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: calls,
      builder: (context, _) {
        final active = calls.active;
        return Stack(
          children: [
            child,
            if (active != null)
              Positioned.fill(
                child: BlocProvider<CallBloc>.value(
                  value: active.bloc,
                  child: CallView(
                    peer: active.call.caller,
                    onClose: calls.dismiss,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
