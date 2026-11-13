import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../domain/entities/call.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/services/call_audio.dart';
import '../bloc/call_bloc.dart';

/// An outgoing voice call to [peer].
///
/// Dials as soon as it opens, and leaving it — the hang-up button, a back
/// gesture, anything that pops the route — hangs up, because the bloc ends
/// the call when it closes.
class CallPage extends StatelessWidget {
  const CallPage({super.key, required this.peer});

  final CallPeer peer;

  /// How long "call ended" stays up before the screen goes away by itself.
  static const _lingerAfterEnd = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CallBloc>(
      create: (context) => CallBloc(
        calls: context.read<CallRepository>(),
        audio: context.read<CallAudio>(),
      )..add(CallStarted(peer.userId)),
      child: BlocListener<CallBloc, CallState>(
        listenWhen: (previous, current) => !previous.isOver && current.isOver,
        listener: (context, state) {
          // A failure or a refused microphone stays on screen: the first needs
          // reading, the second offers the settings.
          if (state.endReason
              case CallEndReason.failed || CallEndReason.microphoneDenied) {
            return;
          }
          Future<void>.delayed(_lingerAfterEnd, () {
            if (context.mounted && context.canPop()) context.pop();
          });
        },
        child: Builder(
          builder: (context) => CallView(
            peer: peer,
            onClose: () {
              if (context.canPop()) context.pop();
            },
          ),
        ),
      ),
    );
  }
}

/// The call screen itself, for whichever [CallBloc] is above it: an outgoing
/// call's route, or an answered call shown over the app.
class CallView extends StatelessWidget {
  const CallView({super.key, required this.peer, required this.onClose});

  final CallPeer peer;

  /// The close button once the call is over.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CallBloc>().state;
    final bloc = context.read<CallBloc>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          child: Column(
            children: [
              const Spacer(),
              AppAvatar(
                name: peer.name,
                photoUrl: peer.photoUrl,
                size: Sizes.avatarXl,
              ),
              VGap.lg,
              Text(
                context.fmt.shortName(peer.name),
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              VGap.sm,
              _StatusLine(state: state),
              if (state.endReason == CallEndReason.microphoneDenied) ...[
                VGap.md,
                TextButton(
                  onPressed: openAppSettings,
                  child: Text(l10n.callOpenSettings),
                ),
              ],
              const Spacer(),
              if (state.isOver)
                _RoundButton(
                  icon: Icons.close,
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  onPressed: onClose,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundButton(
                      icon: state.muted ? Icons.mic_off : Icons.mic_none,
                      label: l10n.callMute,
                      selected: state.muted,
                      onPressed: state.hasAudio
                          ? () => bloc.add(const CallMuteToggled())
                          : null,
                    ),
                    _RoundButton(
                      icon: Icons.call_end,
                      label: l10n.callHangUp,
                      danger: true,
                      onPressed: () => bloc.add(const CallHungUp()),
                    ),
                    _RoundButton(
                      icon: Icons.volume_up_outlined,
                      label: l10n.callSpeaker,
                      selected: state.speakerphone,
                      onPressed: state.hasAudio
                          ? () => bloc.add(const CallSpeakerToggled())
                          : null,
                    ),
                  ],
                ),
              VGap.huge,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = context.text.bodyLarge?.copyWith(
      color: context.colors.onSurfaceVariant,
    );

    if (state.phase == CallPhase.active && state.connectedAt != null) {
      return _CallClock(since: state.connectedAt!, style: style);
    }

    final text = switch (state.phase) {
      CallPhase.idle || CallPhase.dialing => l10n.callConnecting,
      // An answered call is not ringing anywhere: it is waiting for the
      // caller's audio to arrive.
      CallPhase.ringing when state.incoming => l10n.callConnecting,
      CallPhase.ringing => l10n.callRinging,
      CallPhase.active => '',
      CallPhase.ended => _endText(l10n),
    };
    return Text(text, style: style, textAlign: TextAlign.center);
  }

  String _endText(AppStrings l10n) => switch (state.endReason) {
    CallEndReason.noAnswer => l10n.callNoAnswer,
    CallEndReason.rejected => l10n.callRejected,
    CallEndReason.microphoneDenied => l10n.callMicrophoneDenied,
    // The API's own message ("you cannot call yourself") is worth showing;
    // an SDK error or a bare 500 is not, and gets the plain sentence.
    CallEndReason.failed => switch (state.failure) {
      final UnknownFailure f when f.serverMessage == null => l10n.callFailed,
      final Failure f => f.message(l10n),
      null => l10n.callFailed,
    },
    CallEndReason.hungUp || CallEndReason.peerLeft || null => l10n.callEnded,
  };
}

/// mm:ss since [since], ticking once a second.
class _CallClock extends StatefulWidget {
  const _CallClock({required this.since, this.style});

  final DateTime since;
  final TextStyle? style;

  @override
  State<_CallClock> createState() => _CallClockState();
}

class _CallClockState extends State<_CallClock> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: widget.style?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool danger;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = danger
        ? (colors.error, colors.onError)
        : selected
        ? (colors.primary, colors.onPrimary)
        : (colors.surfaceContainerHighest, colors.onSurface);
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      toggled: danger ? null : selected,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: background,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: _size,
                  child: Icon(icon, color: foreground, size: 28),
                ),
              ),
            ),
            VGap.sm,
            Text(label, style: context.text.labelMedium),
          ],
        ),
      ),
    );
  }
}
