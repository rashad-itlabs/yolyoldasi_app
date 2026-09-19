part of 'conversations_bloc.dart';

class ConversationsState extends Equatable {
  const ConversationsState({
    this.status = DataStatus.initial,
    this.page = const Paginated<Conversation>.empty(),
    this.isLoadingMore = false,
    this.failure,
  });

  final DataStatus status;
  final Paginated<Conversation> page;
  final bool isLoadingMore;
  final Failure? failure;

  List<Conversation> get conversations => page.items;
  bool get isEmpty => status.isSuccess && conversations.isEmpty;
  bool get hasMore => page.hasMore;

  ConversationsState copyWith({
    DataStatus? status,
    Paginated<Conversation>? page,
    bool? isLoadingMore,
    Failure? Function()? failure,
  }) {
    return ConversationsState(
      status: status ?? this.status,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, page, isLoadingMore, failure];
}
