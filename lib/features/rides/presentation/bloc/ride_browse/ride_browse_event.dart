part of 'ride_browse_bloc.dart';

sealed class RideBrowseEvent extends Equatable {
  const RideBrowseEvent();

  @override
  List<Object?> get props => const [];
}

class RideBrowseRequested extends RideBrowseEvent {
  const RideBrowseRequested({this.refresh = false});

  /// Keeps the current list on screen while re-reading, for pull-to-refresh.
  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

class RideBrowseMoreRequested extends RideBrowseEvent {
  const RideBrowseMoreRequested();
}

/// Internal: [RideRepository.changes] fired.
class _RideBrowseChanged extends RideBrowseEvent {
  const _RideBrowseChanged();
}
