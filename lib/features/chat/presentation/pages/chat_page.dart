import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/push/pending_deep_link.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../bloc/chat/chat_bloc.dart';

/// One thread. Messages are grouped by day and by sender run, so a burst of
/// replies reads as one block rather than a stack of identical bubbles.
///
/// The API has no realtime transport, so [ChatBloc] re-reads the thread on a
/// timer while this screen is open.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversationId});

  final int conversationId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  PendingDeepLink? _deepLink;

  @override
  void initState() {
    super.initState();
    // Marks this thread as the one on screen, so a push for it draws no banner
    // over the message the user is already watching arrive. Cleared in
    // [dispose] — including when the screen is popped by a deep link into a
    // different thread.
    _deepLink = context.read<AppDependencies>().pendingDeepLink
      ..openConversationId = widget.conversationId;
  }

  @override
  void dispose() {
    if (_deepLink?.openConversationId == widget.conversationId) {
      _deepLink?.openConversationId = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatBloc>(
      create: (context) => ChatBloc(
        chat: context.read<ChatRepository>(),
        conversationId: widget.conversationId,
      )..add(const ChatStarted()),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: Motion.normal,
      curve: Motion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;

    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          previous.page.items.length != current.page.items.length ||
          previous.sendStatus != current.sendStatus,
      listener: (context, state) {
        if (state.sendStatus.isSuccess) {
          _controller.clear();
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        }
        final failure = state.failure;
        if (state.sendStatus.isFailure && failure != null) {
          AppFeedback.error(context, failure.message(l10n));
        }
      },
      builder: (context, state) {
        final bloc = context.read<ChatBloc>();
        final other = state.conversation?.otherUser;

        return AppScaffold(
          titleWidget: Row(
            children: [
              AppAvatar(
                name: other?.fullName,
                photoUrl: other?.photoUrl,
                size: Sizes.avatarSm + 4,
                isVerified: other?.hasDriverProfile ?? false,
              ),
              HGap.md,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fmt.shortName(other?.fullName),
                      style: context.text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(l10n.bookingTitle, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (state.bookingId != null)
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined),
                tooltip: l10n.bookingTitle,
                onPressed: () =>
                    context.push(Routes.bookingDetail(state.bookingId!)),
              ),
          ],
          body: Column(
            children: [
              Expanded(child: _messages(context, state)),
              if (state.isLocked)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.md,
                    Gap.page,
                    Gap.md + context.bottomSafeArea,
                  ),
                  child: Text(
                    l10n.conversationLocked,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall,
                  ),
                )
              else
                _Composer(
                  controller: _controller,
                  isSending: state.sendStatus.isInProgress,
                  onChanged: (value) => bloc.add(ChatDraftChanged(value)),
                  // The server knows who is writing from the token; the id is
                  // only needed to build the optimistic bubble.
                  onSend: state.canSend
                      ? () => bloc.add(
                          ChatMessageSent(
                            senderId:
                                context.read<SessionBloc>().state.userId ?? 0,
                          ),
                        )
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _messages(BuildContext context, ChatState state) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final bloc = context.read<ChatBloc>();

    if (state.status.isFirstLoad) return const LoadingState();
    if (state.status.isFailure) {
      return ErrorState(
        failure: state.failure,
        onRetry: () => bloc.add(const ChatStarted()),
      );
    }

    final messages = state.messages;
    if (messages.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: l10n.noMessages,
        message: l10n.noMessagesBody,
        compact: true,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
      itemCount: messages.length + (state.hasOlder ? 1 : 0),
      itemBuilder: (context, rawIndex) {
        // Older messages are at the top, so "load more" sits there too.
        if (state.hasOlder && rawIndex == 0) {
          return Center(
            child: TextButton(
              onPressed: () => bloc.add(const ChatOlderRequested()),
              child: Text(l10n.loadMore),
            ),
          );
        }

        final index = state.hasOlder ? rawIndex - 1 : rawIndex;
        final message = messages[index];
        final previous = index == 0 ? null : messages[index - 1];

        final showDay =
            previous == null ||
            !_sameDay(previous.createdAt, message.createdAt);
        final grouped =
            previous != null &&
            previous.senderId == message.senderId &&
            !showDay &&
            message.createdAt.difference(previous.createdAt).inMinutes < 5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDay)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Center(
                  child: Text(
                    fmt.dayLabel(message.createdAt),
                    style: context.text.labelSmall?.copyWith(
                      color: context.palette.textTertiary,
                    ),
                  ),
                ),
              ),
            _Bubble(message: message, grouped: grouped),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.grouped});

  final ChatMessage message;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;
    final isMine = message.isMine;

    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMine || grouped ? Radii.lg : Radii.xs),
      topRight: Radius.circular(!isMine || grouped ? Radii.lg : Radii.xs),
      bottomLeft: const Radius.circular(Radii.lg),
      bottomRight: const Radius.circular(Radii.lg),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        // A message still in flight is dimmed until the server echoes it back.
        opacity: message.isPending ? 0.6 : 1,
        child: Container(
          constraints: BoxConstraints(maxWidth: context.screenWidth * 0.74),
          margin: EdgeInsets.only(top: grouped ? Gap.xs : Gap.md),
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
          decoration: BoxDecoration(
            color: isMine ? colors.primary : palette.surfaceElevated,
            borderRadius: radius,
            border: isMine ? null : Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                style: context.text.bodyLarge?.copyWith(
                  color: isMine ? colors.onPrimary : palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.fmt.time(message.createdAt),
                    style: context.text.labelSmall?.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: isMine
                          ? colors.onPrimary.withValues(alpha: 0.75)
                          : palette.textTertiary,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 3),
                    Icon(
                      switch (message.status) {
                        MessageStatus.sending => Icons.schedule_rounded,
                        MessageStatus.failed => Icons.error_outline_rounded,
                        MessageStatus.sent =>
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                      },
                      size: 13,
                      color: message.hasFailed
                          ? colors.error
                          : colors.onPrimary.withValues(alpha: 0.8),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Gap.md,
        Gap.sm,
        Gap.md,
        Gap.sm + context.bottomSafeArea,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: AppRules.maxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              style: context.text.bodyLarge,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: context.l10n.typeMessage,
                counterText: '',
                filled: true,
                fillColor: palette.surfaceSunken,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                border: const OutlineInputBorder(
                  borderRadius: Radii.xlAll,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: Radii.xlAll,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: Radii.xlAll,
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
            ),
          ),
          HGap.sm,
          SizedBox(
            width: 46,
            height: 46,
            child: IconButton.filled(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
