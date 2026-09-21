import 'package:equatable/equatable.dart';

/// The invite screen's numbers — API.md §21.
///
/// The reward is deliberately not money. With no payment layer in the product,
/// cash invites would pull in fake accounts and would hurt the moment they were
/// switched off. What a driver actually lacks is visibility, so that is what
/// the reward is: their listings ride at the top of search for a while.
///
/// It is also paid on the invitee's **first real trip**, not on sign-up. Ten
/// phone numbers are easy; ten trips with reviews are not.
class ReferralSummary extends Equatable {
  const ReferralSummary({
    this.code = '',
    this.invitedCount = 0,
    this.activeCount = 0,
    this.rewardDays = 7,
    this.boostUntil,
  });

  /// Six characters, no `0/O` or `1/I/L` — it gets read aloud and typed by
  /// hand into a WhatsApp message.
  final String code;

  /// How many accounts signed up with this code.
  final int invitedCount;

  /// How many of those went on to take or offer a trip — the ones that paid.
  final int activeCount;

  final int rewardDays;

  /// When the current boost runs out. Null when there is none.
  final DateTime? boostUntil;

  static const ReferralSummary empty = ReferralSummary();

  bool get hasCode => code.isNotEmpty;

  bool get isBoosted => boostUntil != null && boostUntil!.isAfter(DateTime.now());

  /// Invites that have not turned into a trip yet. Worth showing separately:
  /// it tells the user the reward is still coming rather than lost.
  int get pendingCount => (invitedCount - activeCount).clamp(0, invitedCount);

  @override
  List<Object?> get props => [
    code,
    invitedCount,
    activeCount,
    rewardDays,
    boostUntil,
  ];
}
