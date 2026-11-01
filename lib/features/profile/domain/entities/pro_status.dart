import 'package:equatable/equatable.dart';

/// The driver's PRO tier, as `GET /driver/profile` reports it (API.md §7).
///
/// PRO is free for now: a one-off trial the driver starts from the app, or
/// time an admin grants. What it buys is real, though — the driver's rides
/// are ordered first in search, and a PRO badge sits next to their name.
class ProStatus extends Equatable {
  const ProStatus({
    this.isActive = false,
    this.until,
    this.trialAvailable = false,
    this.trialDays = 30,
  });

  final bool isActive;

  /// When it runs out. Only sent while [isActive].
  final DateTime? until;

  /// The free trial has not been used yet.
  final bool trialAvailable;

  /// How long the trial runs — the server's number, so the offer and the
  /// grant can never disagree.
  final int trialDays;

  @override
  List<Object?> get props => [isActive, until, trialAvailable, trialDays];
}
