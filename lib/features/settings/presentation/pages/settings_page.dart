import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../profile/domain/repositories/user_repository.dart';
import '../../../profile/presentation/bloc/notification_preferences/notification_preferences_bloc.dart';
import '../../../profile/presentation/widgets/profile_tile.dart';
import '../bloc/settings/settings_bloc.dart';

/// Appearance, language, notifications and the account danger zone.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<SettingsBloc, SettingsState>(
      listenWhen: (previous, current) =>
          previous.syncedUser != current.syncedUser,
      // A language change is also a `PATCH /me`, so the session takes the
      // updated profile rather than going stale.
      listener: (context, state) {
        final user = state.syncedUser;
        if (user != null) {
          context.read<SessionBloc>().add(SessionUserUpdated(user));
        }
      },
      builder: (context, settings) {
        final bloc = context.read<SettingsBloc>();
        final languageLabel = switch (settings.languageCode) {
          'ru' => l10n.languageRu,
          'en' => l10n.languageEn,
          'az' => l10n.languageAz,
          _ => l10n.themeSystem,
        };

        return AppScaffold(
          title: l10n.settings,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.xxxl,
            ),
            children: [
              // -------------------------------------------------- appearance
              Text(
                l10n.appearance.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  color: context.palette.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              VGap.sm,
              AppSegmented<ThemeMode>(
                value: settings.themeMode,
                onChanged: (value) => bloc.add(SettingsThemeChanged(value)),
                options: [
                  (
                    value: ThemeMode.system,
                    label: l10n.themeSystem,
                    icon: Icons.brightness_auto_rounded,
                  ),
                  (
                    value: ThemeMode.light,
                    label: l10n.themeLight,
                    icon: Icons.light_mode_rounded,
                  ),
                  (
                    value: ThemeMode.dark,
                    label: l10n.themeDark,
                    icon: Icons.dark_mode_rounded,
                  ),
                ],
              ),

              VGap.xl,
              ProfileSection(
                children: [
                  ProfileTile(
                    icon: Icons.translate_rounded,
                    label: l10n.language,
                    value: languageLabel,
                    onTap: () => _showLanguageSheet(context),
                  ),
                  ProfileTile(
                    icon: Icons.notifications_none_rounded,
                    label: l10n.notificationSettings,
                    onTap: () => _showNotificationSheet(context),
                  ),
                ],
              ),

              // ----------------------------------------------------- support
              VGap.xl,
              ProfileSection(
                title: l10n.support.toUpperCase(),
                children: [
                  ProfileTile(
                    icon: Icons.help_outline_rounded,
                    label: l10n.helpCenter,
                    onTap: () => _openUrl(AppLinks.helpUrl),
                  ),
                  ProfileTile(
                    icon: Icons.mail_outline_rounded,
                    label: l10n.contactSupport,
                    value: AppLinks.supportEmail,
                    onTap: () => _openUrl('mailto:${AppLinks.supportEmail}'),
                  ),
                ],
              ),

              // ------------------------------------------------------- legal
              VGap.xl,
              ProfileSection(
                title: l10n.legal.toUpperCase(),
                children: [
                  ProfileTile(
                    icon: Icons.description_outlined,
                    label: l10n.termsOfUse,
                    onTap: () => _openUrl(AppLinks.termsUrl),
                  ),
                  ProfileTile(
                    icon: Icons.privacy_tip_outlined,
                    label: l10n.privacyPolicy,
                    onTap: () => _openUrl(AppLinks.privacyUrl),
                  ),
                  ProfileTile(
                    icon: Icons.info_outline_rounded,
                    label: l10n.aboutApp,
                    value: context.read<AppDependencies>().version.display,
                    onTap: null,
                  ),
                ],
              ),

              // -------------------------------------------------- danger zone
              VGap.xl,
              const _AccountSection(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLanguageSheet(BuildContext context) async {
    final l10n = context.l10n;
    final settings = context.read<SettingsBloc>();
    final isSignedIn = context.read<SessionBloc>().state.isSignedIn;

    await AppFeedback.sheet<void>(
      context,
      builder: (sheetContext) => BlocProvider<SettingsBloc>.value(
        value: settings,
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) => SheetScaffold(
            title: l10n.language,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final locale in AppLocalizations.supportedLocales) ...[
                    SelectableTile(
                      title: switch (locale.languageCode) {
                        'ru' => l10n.languageRu,
                        'en' => l10n.languageEn,
                        _ => l10n.languageAz,
                      },
                      selected: state.languageCode == locale.languageCode,
                      onTap: () {
                        settings.add(
                          SettingsLanguageChanged(
                            locale.languageCode,
                            // `language_code` belongs to the account, but
                            // there is no account to write it to yet.
                            persistToAccount: isSignedIn,
                          ),
                        );
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                    VGap.sm,
                  ],
                  SelectableTile(
                    title: l10n.themeSystem,
                    selected: state.languageCode == null,
                    onTap: () {
                      settings.add(
                        const SettingsLanguageChanged(
                          null,
                          persistToAccount: false,
                        ),
                      );
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  VGap.md,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationSheet(BuildContext context) async {
    final l10n = context.l10n;
    final users = context.read<UserRepository>();
    final seed = context
        .read<SessionBloc>()
        .state
        .user
        ?.notificationPreferences;

    await AppFeedback.sheet<void>(
      context,
      builder: (_) => BlocProvider<NotificationPreferencesBloc>(
        create: (_) =>
            NotificationPreferencesBloc(users: users)
              ..add(NotificationPreferencesRequested(seed: seed)),
        child:
            BlocBuilder<
              NotificationPreferencesBloc,
              NotificationPreferencesState
            >(
              builder: (context, state) {
                final bloc = context.read<NotificationPreferencesBloc>();

                Widget toggle(NotificationChannel channel, String title) {
                  return SwitchListTile.adaptive(
                    value: state.valueOf(channel),
                    // API.md §4: `push_enabled` is the master switch, so the rest
                    // are disabled while it is off.
                    onChanged: state.isMutedBy(channel)
                        ? null
                        : (value) => bloc.add(
                            NotificationPreferenceToggled(channel, value),
                          ),
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                  );
                }

                return SheetScaffold(
                  title: l10n.notificationSettings,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        toggle(
                          NotificationChannel.pushEnabled,
                          l10n.pushNotifications,
                        ),
                        toggle(
                          NotificationChannel.bookings,
                          l10n.bookingNotifications,
                        ),
                        toggle(
                          NotificationChannel.messages,
                          l10n.messageNotifications,
                        ),
                        toggle(
                          NotificationChannel.reminders,
                          l10n.reminderNotifications,
                        ),
                        toggle(
                          NotificationChannel.marketing,
                          l10n.marketingNotifications,
                        ),
                        VGap.md,
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}

/// Sign out and the irreversible account deletion.
class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocListener<SessionBloc, SessionState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) =>
          AppFeedback.error(context, state.failure!.message(l10n)),
      child: ProfileSection(
        title: l10n.account.toUpperCase(),
        children: [
          ProfileTile(
            icon: Icons.logout_rounded,
            label: l10n.logout,
            onTap: () async {
              final session = context.read<SessionBloc>();
              final confirmed = await AppFeedback.confirm(
                context,
                title: l10n.logoutConfirm,
                confirmLabel: l10n.logout,
                isDestructive: true,
              );
              if (confirmed) session.add(const SessionSignOutRequested());
            },
          ),
          ProfileTile(
            icon: Icons.delete_forever_outlined,
            label: l10n.deleteAccount,
            isDestructive: true,
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  /// `DELETE /auth/account` soft-deletes the account, anonymises the phone
  /// number and revokes every token — API.md §3 calls it irreversible, so it is
  /// gated behind typing a keyword.
  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final session = context.read<SessionBloc>();
    final controller = TextEditingController();

    final confirmed = await AppFeedback.sheet<bool>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          final matches =
              controller.text.trim().toUpperCase() ==
              l10n.deleteAccountKeyword.toUpperCase();
          return SheetScaffold(
            title: l10n.deleteAccountTitle,
            subtitle: l10n.deleteAccountWarning,
            action: AppButton.danger(
              label: l10n.deleteAccount,
              onPressed: matches
                  ? () => Navigator.of(sheetContext).pop(true)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: AppTextField(
                controller: controller,
                hint: l10n.deleteAccountConfirmHint,
                isRequired: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
            ),
          );
        },
      ),
    );

    controller.dispose();
    if (confirmed == true) {
      session.add(const SessionDeleteAccountRequested());
    }
  }
}
