import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../shell/presentation/bloc/badges/badges_bloc.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../bloc/notifications/notifications_bloc.dart';

/// The notification centre — `GET /notifications` (API.md §13).
///
/// Push delivery is not live on the backend yet; this list is what the app
/// shows in the meantime, and the payload shape will not change when it is.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsBloc>(
      create: (context) => NotificationsBloc(
        notifications: context.read<NotificationRepository>(),
      )..add(const NotificationsRequested()),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  /// API.md §13: all three ids can be null at once, when the object the
  /// notification is about has been deleted. That is a dead link, and saying
  /// so beats opening a blank screen.
  void _open(BuildContext context, AppNotification item) {
    final bloc = context.read<NotificationsBloc>();
    if (!item.isRead) {
      bloc.add(NotificationRead(item.id));
      context.read<BadgesBloc>().add(const BadgesRefreshed());
    }

    switch (item.target) {
      case ConversationTarget(:final conversationId):
        context.push(Routes.conversation(conversationId));
      case BookingTarget(:final bookingId):
        context.push(Routes.bookingDetail(bookingId));
      case RideTarget(:final rideId):
        context.push(Routes.rideDetail(rideId));
      case _:
        AppFeedback.error(context, context.l10n.linkUnavailableBody);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;

    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        final bloc = context.read<NotificationsBloc>();

        return AppScaffold(
          title: l10n.notifications,
          actions: [
            IconButton(
              icon: Icon(
                state.unreadOnly
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_outlined,
              ),
              tooltip: l10n.filters,
              onPressed: () => bloc.add(
                NotificationsFilterChanged(unreadOnly: !state.unreadOnly),
              ),
            ),
            if (state.unreadCount > 0)
              TextButton(
                onPressed: () {
                  bloc.add(const NotificationsAllRead());
                  context.read<BadgesBloc>().add(const BadgesRefreshed());
                },
                child: Text(l10n.markAllRead),
              ),
            HGap.sm,
          ],
          body: switch (state) {
            NotificationsState(status: final s) when s.isFirstLoad =>
              const ListSkeleton(count: 4),
            NotificationsState(status: final s) when s.isFailure => ErrorState(
              failure: state.failure,
              onRetry: () => bloc.add(const NotificationsRequested()),
            ),
            NotificationsState(notifications: final items) when items.isEmpty =>
              EmptyState(
                icon: Icons.notifications_none_rounded,
                title: l10n.noNotifications,
                message: l10n.noNotificationsBody,
              ),
            _ => RefreshIndicator(
              onRefresh: () async {
                bloc.add(const NotificationsRequested(refresh: true));
                context.read<BadgesBloc>().add(const BadgesRefreshed());
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => Padding(
                  padding: const EdgeInsets.only(left: 72),
                  child: Divider(height: 1, color: palette.border),
                ),
                itemBuilder: (context, index) {
                  if (index == state.notifications.length) {
                    return Center(
                      child: TextButton(
                        onPressed: () =>
                            bloc.add(const NotificationsMoreRequested()),
                        child: Text(l10n.loadMore),
                      ),
                    );
                  }

                  final item = state.notifications[index];
                  final (icon, tone) = _visualFor(context, item.type);
                  final actor = item.actor;

                  return Material(
                    color: item.isRead
                        ? Colors.transparent
                        : context.colors.primaryContainer.withValues(
                            alpha: 0.28,
                          ),
                    child: InkWell(
                      onTap: () => _open(context, item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.page,
                          vertical: Gap.md,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (actor != null)
                              AppAvatar(
                                name: actor.fullName,
                                photoUrl: actor.photoUrl,
                                size: Sizes.avatarMd - 4,
                              )
                            else
                              Container(
                                width: Sizes.avatarMd - 4,
                                height: Sizes.avatarMd - 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tone.withValues(alpha: 0.14),
                                ),
                                child: Icon(icon, size: 18, color: tone),
                              ),
                            HGap.lg,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.byKey(item.type.titleKey),
                                          style: context.text.titleSmall
                                              ?.copyWith(
                                                fontWeight: item.isRead
                                                    ? FontWeight.w500
                                                    : FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      HGap.sm,
                                      Text(
                                        fmt.relative(item.createdAt),
                                        style: context.text.labelSmall
                                            ?.copyWith(
                                              color: palette.textTertiary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _subtitle(context, item),
                                    style: context.text.bodySmall?.copyWith(
                                      color: item.isDeadLink
                                          ? palette.textTertiary
                                          : null,
                                      fontStyle: item.isDeadLink
                                          ? FontStyle.italic
                                          : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          },
        );
      },
    );
  }

  /// The API sends no rendered body — only `payload` and an `actor` — so the
  /// line under the title is built here.
  String _subtitle(BuildContext context, AppNotification item) {
    final l10n = context.l10n;
    if (item.isDeadLink) return l10n.linkUnavailableTitle;

    final actor = item.actor?.fullName;
    final seats = item.seats;
    return [
      if (actor != null && actor.isNotEmpty) context.fmt.shortName(actor),
      if (seats != null) l10n.seats(seats),
    ].join(' · ');
  }

  (IconData, Color) _visualFor(BuildContext context, NotificationType type) {
    final palette = context.palette;
    return switch (type) {
      NotificationType.bookingRequested => (
        Icons.person_add_alt_1_rounded,
        context.colors.primary,
      ),
      NotificationType.bookingConfirmed => (
        Icons.check_circle_rounded,
        palette.success,
      ),
      NotificationType.bookingRejected => (
        Icons.cancel_rounded,
        palette.danger,
      ),
      NotificationType.bookingCancelled => (
        Icons.event_busy_rounded,
        palette.warning,
      ),
      NotificationType.rideReminder => (Icons.alarm_rounded, palette.info),
      NotificationType.rideCancelled => (
        Icons.no_transfer_rounded,
        palette.danger,
      ),
      NotificationType.newMessage => (
        Icons.chat_bubble_rounded,
        context.colors.primary,
      ),
      NotificationType.reviewRequest => (Icons.star_rounded, palette.accent),
      NotificationType.documentsApproved => (
        Icons.verified_rounded,
        palette.success,
      ),
      NotificationType.documentsRejected => (
        Icons.gpp_bad_rounded,
        palette.danger,
      ),
      // A type this build does not know. Neutral on purpose: borrowing another
      // type's icon is how the old fallback misled people.
      NotificationType.unknown => (
        Icons.notifications_none_rounded,
        palette.textTertiary,
      ),
    };
  }
}
