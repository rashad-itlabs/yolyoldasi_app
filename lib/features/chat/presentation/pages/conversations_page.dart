import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../shell/presentation/bloc/badges/badges_bloc.dart';
import '../../domain/repositories/chat_repository.dart';
import '../bloc/conversations/conversations_bloc.dart';

/// Inbox of booking-scoped threads — `GET /conversations` (API.md §11).
class ConversationsPage extends StatelessWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConversationsBloc>(
      create: (context) =>
          ConversationsBloc(chat: context.read<ChatRepository>())
            ..add(const ConversationsRequested()),
      child: const _ConversationsView(),
    );
  }
}

class _ConversationsView extends StatelessWidget {
  const _ConversationsView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final palette = context.palette;
    final userId = context.select<SessionBloc, int?>(
      (bloc) => bloc.state.userId,
    );

    return AppScaffold(
      title: l10n.messages,
      showBackButton: false,
      body: BlocBuilder<ConversationsBloc, ConversationsState>(
        builder: (context, state) {
          final bloc = context.read<ConversationsBloc>();

          if (state.status.isFirstLoad) return const ListSkeleton(count: 4);
          if (state.status.isFailure) {
            return ErrorState(
              failure: state.failure,
              onRetry: () => bloc.add(const ConversationsRequested()),
            );
          }

          final conversations = state.conversations;
          if (conversations.isEmpty) {
            return EmptyState(
              icon: Icons.forum_outlined,
              title: l10n.noConversations,
              message: l10n.noConversationsBody,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              bloc.add(const ConversationsRequested(refresh: true));
              context.read<BadgesBloc>().add(const BadgesRefreshed());
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => Padding(
                padding: const EdgeInsets.only(left: 76),
                child: Divider(height: 1, color: palette.border),
              ),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final other = conversation.otherUser;
                final unread = conversation.unreadCount;
                final isMine =
                    userId != null && conversation.isLastSender(userId);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Gap.page,
                    vertical: Gap.xs,
                  ),
                  shape: const RoundedRectangleBorder(),
                  leading: AppAvatar(
                    name: other?.fullName,
                    photoUrl: other?.photoUrl,
                    size: Sizes.avatarMd,
                    isVerified: other?.hasDriverProfile ?? false,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fmt.shortName(other?.fullName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          fmt.relative(conversation.lastMessageAt!),
                          style: context.text.labelSmall?.copyWith(
                            color: unread > 0
                                ? context.colors.primary
                                : palette.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        if (conversation.isLocked) ...[
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: palette.textTertiary,
                          ),
                          HGap.xs,
                        ] else if (isMine) ...[
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: palette.textTertiary,
                          ),
                          HGap.xs,
                        ],
                        Expanded(
                          child: Text(
                            conversation.lastMessage.isEmpty
                                ? l10n.noMessages
                                : conversation.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: unread > 0
                                  ? palette.textPrimary
                                  : palette.textSecondary,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          HGap.sm,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primary,
                              borderRadius: Radii.pillAll,
                            ),
                            child: Text(
                              '$unread',
                              style: context.text.labelSmall?.copyWith(
                                color: context.colors.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  onTap: () async {
                    await context.push(Routes.conversation(conversation.id));
                    if (!context.mounted) return;
                    // Opening the thread marks it read server-side, so both
                    // the row and the tab badge are stale on the way back.
                    bloc.add(ConversationMarkedRead(conversation.id));
                    context.read<BadgesBloc>().add(const BadgesRefreshed());
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
