import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/analytics.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/referral.dart';
import '../../domain/repositories/user_repository.dart';

/// "Invite a friend."
///
/// The reward is visibility, not money: with no payment layer, cash invites
/// would pull in fake accounts and would sting the day they stopped. What a
/// driver actually lacks is being seen, so that is what an invite buys.
///
/// No bloc. One read, one share button, nothing to keep in sync — a bloc here
/// would be three files standing in for a `FutureBuilder`.
class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  late Future<Result<ReferralSummary>> _future = _load();

  Future<Result<ReferralSummary>> _load() =>
      context.read<UserRepository>().referral();

  void _reload() => setState(() => _future = _load());

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    AppFeedback.success(context, context.l10n.copied);
  }

  Future<void> _share(String code) async {
    final l10n = context.l10n;
    context.read<Analytics>().log(Ev.referralShared);

    await SharePlus.instance.share(
      ShareParams(text: '${l10n.referralShareText} $code'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.referral,
      body: FutureBuilder<Result<ReferralSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingState();

          return switch (snapshot.data!) {
            Err(:final failure) => ErrorState(
              failure: failure,
              onRetry: _reload,
            ),
            Ok(:final value) => _ReferralBody(
              summary: value,
              onCopy: () => _copy(value.code),
              onShare: () => _share(value.code),
            ),
          };
        },
      ),
    );
  }
}

class _ReferralBody extends StatelessWidget {
  const _ReferralBody({
    required this.summary,
    required this.onCopy,
    required this.onShare,
  });

  final ReferralSummary summary;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.xxxl),
      children: [
        Text(l10n.referralTitle, style: context.text.headlineSmall),
        VGap.sm,
        Text(
          l10n.referralBody,
          style: context.text.bodyMedium?.copyWith(
            color: palette.textSecondary,
          ),
        ),
        VGap.xl,

        // The code, big enough to read aloud down a phone line — which is how
        // half of these will actually travel.
        AppCard(
          onTap: onCopy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.referralCode,
                style: context.text.labelMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              VGap.sm,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.hasCode ? summary.code : '—',
                      style: context.text.headlineMedium?.copyWith(
                        letterSpacing: 4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Icon(Icons.copy_rounded, color: palette.textTertiary),
                ],
              ),
            ],
          ),
        ),
        VGap.lg,

        AppButton(
          label: l10n.referralShare,
          icon: Icons.ios_share_rounded,
          onPressed: summary.hasCode ? onShare : null,
        ),
        VGap.xl,

        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: l10n.referralInvited,
                value: '${summary.invitedCount}',
              ),
            ),
            HGap.md,
            Expanded(
              child: _StatTile(
                // The one that actually pays: an invite only earns the reward
                // once the person takes or offers a trip.
                label: l10n.referralActive,
                value: '${summary.activeCount}',
              ),
            ),
          ],
        ),

        if (summary.isBoosted) ...[
          VGap.lg,
          AppCard(
            child: Row(
              children: [
                StatusChip(
                  label: l10n.referralBoostActive,
                  tone: ChipTone.success,
                  icon: Icons.trending_up_rounded,
                ),
                const Spacer(),
                Text(
                  '${l10n.referralBoostUntil}: '
                  '${fmt.dayLabel(summary.boostUntil!)}',
                  style: context.text.labelMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: context.text.headlineSmall),
          VGap.xs,
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
