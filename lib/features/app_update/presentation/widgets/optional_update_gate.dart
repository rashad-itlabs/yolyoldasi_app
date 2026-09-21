import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../bloc/app_update/app_update_bloc.dart';
import '../store_link.dart';
import 'optional_update_sheet.dart';

/// Raises the optional-update sheet once, over whatever [child] is showing.
///
/// Wrapped around the tab shell rather than hooked into app startup, for a
/// plain reason: a modal sheet needs a [Navigator] above it, and the startup
/// widget sits above the one the router builds. This is also the first screen
/// with anything worth interrupting.
///
/// The forced case never reaches here — the router has already replaced the
/// shell with the update screen.
class OptionalUpdateGate extends StatefulWidget {
  const OptionalUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<OptionalUpdateGate> createState() => _OptionalUpdateGateState();
}

class _OptionalUpdateGateState extends State<OptionalUpdateGate> {
  /// Once per launch, whatever the answer. The bloc remembers the answer
  /// across launches; this only stops the same launch asking twice — on a
  /// resume, say, when the check runs again and comes back with the same
  /// verdict it already acted on.
  bool _asked = false;

  @override
  void initState() {
    super.initState();

    // The launch check usually lands before this widget exists, so the state
    // is already sitting there and no listener would ever fire for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAsk(context.read<AppUpdateBloc>().state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppUpdateBloc, AppUpdateState>(
      listenWhen: (previous, current) =>
          previous.showsOptional != current.showsOptional,
      listener: (context, state) => _maybeAsk(state),
      child: widget.child,
    );
  }

  Future<void> _maybeAsk(AppUpdateState state) async {
    if (_asked || !state.showsOptional) return;
    _asked = true;

    final update = state.update;
    final bloc = context.read<AppUpdateBloc>();

    final wantsUpdate = await OptionalUpdateSheet.show(context, update);

    // Recorded whichever way it went. Someone who tapped "Yenilə" and walked
    // to the store has been asked about this release just as surely as
    // someone who tapped "Sonra" — and the app cannot tell whether they went
    // through with it, so asking again on the way back would be nagging.
    bloc.add(const AppUpdateDismissed());

    if (wantsUpdate != true) return;

    final opened = await StoreLink.open(update.storeUrl);
    if (opened || !mounted) return;
    AppFeedback.error(context, context.l10n.updateStoreUnavailable);
  }
}
