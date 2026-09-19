import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../bloc/session/session_bloc.dart';

/// Shown when the API answers 403 "hesab bloklanıb" (API.md §3).
///
/// There is no endpoint that explains why, so the server's own message is all
/// there is to show — which is exactly what [FailureMessage] surfaces.
class BlockedPage extends StatelessWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final reason = state.failure?.serverMessage;

        return AppScaffold(
          showBackButton: false,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.palette.dangerContainer,
                    ),
                    child: Icon(
                      Icons.block_rounded,
                      size: 40,
                      color: context.palette.danger,
                    ),
                  ),
                  VGap.xl,
                  Text(
                    l10n.blocked,
                    style: context.text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  VGap.sm,
                  Text(
                    l10n.errPermissionDenied,
                    style: context.text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (reason != null && reason.isNotEmpty) ...[
                    VGap.xl,
                    InfoBanner(
                      tone: BannerTone.danger,
                      title: l10n.reportReason,
                      message: reason,
                    ),
                  ],
                  VGap.xxxl,
                  AppButton.secondary(
                    label: l10n.contactSupport,
                    icon: Icons.mail_outline_rounded,
                    onPressed: () =>
                        launchUrl(Uri.parse('mailto:${AppLinks.supportEmail}')),
                  ),
                  VGap.md,
                  AppButton.ghost(
                    label: l10n.logout,
                    expand: true,
                    onPressed: () => context.read<SessionBloc>().add(
                      const SessionSignOutRequested(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
