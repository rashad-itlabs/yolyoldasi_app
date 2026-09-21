import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../bloc/app_update/app_update_bloc.dart';
import '../store_link.dart';

/// The wall. Shown when `GET /app-version` answers `required`, and it is the
/// only thing the router will route to while that holds.
///
/// There is no way past it on purpose — no back button, no dismiss, no
/// "continue anyway". The screen's whole job is to be a dead end with exactly
/// one exit, and the system back gesture is caught too, because on Android it
/// is the reflex that would otherwise drop the user onto whatever was
/// underneath.
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final state = context.watch<AppUpdateBloc>().state;
    final update = state.update;

    return PopScope(
      canPop: false,
      child: AppScaffold(
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
                    color: palette.infoContainer,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 40,
                    color: palette.info,
                  ),
                ),
                VGap.xl,
                Text(
                  l10n.updateRequiredTitle,
                  style: context.text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                VGap.sm,
                Text(
                  // The admin's own wording when there is one — it can say
                  // *why*, which generic copy never can.
                  update.message ?? l10n.updateRequiredBody,
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                if (update.latestVersion != null) ...[
                  VGap.xl,
                  InfoBanner(
                    icon: Icons.new_releases_outlined,
                    title: l10n.updateNewVersion(update.latestVersion!),
                    message: [
                      if (update.minVersion != null)
                        l10n.updateMinVersion(update.minVersion!),
                      // The build in the user's hands — the first thing
                      // support will ask for if the wall is wrong.
                      if (state.installed.isKnown)
                        '${l10n.version}: ${state.installed.display}',
                    ].join('\n'),
                  ),
                ],

                VGap.xxxl,
                AppButton(
                  label: l10n.updateNow,
                  icon: Icons.download_rounded,
                  onPressed: () => _openStore(context, update.storeUrl),
                ),
                VGap.md,
                // Not an escape hatch from the wall — a way to report one that
                // should not be there. A wrong store link or a mistyped
                // minimum would otherwise leave the user with nobody to tell.
                AppButton.ghost(
                  label: l10n.contactSupport,
                  icon: Icons.mail_outline_rounded,
                  expand: true,
                  onPressed: () => launchUrl(
                    Uri.parse('mailto:${AppLinks.supportEmail}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context, String? storeUrl) async {
    final opened = await StoreLink.open(storeUrl);
    if (opened || !context.mounted) return;
    AppFeedback.error(context, context.l10n.updateStoreUnavailable);
  }
}
