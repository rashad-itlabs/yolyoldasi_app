/// The lifecycle every data-loading state in the app shares.
///
/// Having one enum rather than a sealed state per screen keeps the widgets
/// uniform — `AppStates` switches on exactly these four, so a new screen gets
/// its loading, empty and error rendering for free.
enum DataStatus {
  /// Nothing asked for yet.
  initial,

  /// First load in flight; the screen shows a skeleton.
  loading,

  /// A reload on top of data that is already on screen. Kept separate from
  /// [loading] so a pull-to-refresh does not blank the list.
  refreshing,

  success,
  failure;

  bool get isInitial => this == DataStatus.initial;
  bool get isLoading => this == DataStatus.loading;
  bool get isRefreshing => this == DataStatus.refreshing;
  bool get isSuccess => this == DataStatus.success;
  bool get isFailure => this == DataStatus.failure;

  /// True while the screen is waiting on the network for any reason.
  bool get isBusy => isLoading || isRefreshing;

  /// True when a full-screen spinner is the right thing to show — i.e. there
  /// is nothing on screen yet to refresh.
  bool get isFirstLoad => isInitial || isLoading;
}

/// The lifecycle of a one-shot action: submitting a form, confirming a
/// booking, sending a message.
///
/// Distinct from [DataStatus] because the UI reacts differently — a
/// `BlocListener` pops a screen or shows a snack bar on [success] / [failure],
/// and those are edge-triggered rather than rendered.
enum ActionStatus {
  idle,
  inProgress,
  success,
  failure;

  bool get isIdle => this == ActionStatus.idle;
  bool get isInProgress => this == ActionStatus.inProgress;
  bool get isSuccess => this == ActionStatus.success;
  bool get isFailure => this == ActionStatus.failure;

  /// Whether the submit button should be disabled and spinning.
  bool get isBusy => isInProgress;
}
