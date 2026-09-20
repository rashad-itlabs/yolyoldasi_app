import 'package:flutter/widgets.dart';

/// How much room the app has, and what that should change.
///
/// Decided by the **shortest side**, not the width. A phone turned sideways is
/// 900pt wide and still a phone: it has no more room for a second column, and
/// scaling its type up would push content off the screen. An iPad is a tablet
/// in either orientation. Shortest side is the only measure that says which is
/// which.
///
/// The app is one column everywhere on purpose — a ride card, a chat thread and
/// a booking are all single-subject screens. What a bigger screen changes is
/// not the number of columns but the *scale*: a 13-inch tablet is held at about
/// the same distance as a phone, so phone-sized type on it reads as small, and
/// a 560pt column marooned in the middle of 1032pt reads as broken.
enum LayoutSize {
  /// Phones, in either orientation.
  compact(typeScale: 1, contentWidth: 560, pagePadding: 20),

  /// Small tablets — 8-inch class, and phones in split view.
  medium(typeScale: 1.1, contentWidth: 660, pagePadding: 28),

  /// 11-inch tablets and up.
  expanded(typeScale: 1.18, contentWidth: 740, pagePadding: 36);

  const LayoutSize({
    required this.typeScale,
    required this.contentWidth,
    required this.pagePadding,
  });

  /// Multiplier applied to every font size in the theme.
  ///
  /// Deliberately modest. It stacks on top of the reader's own accessibility
  /// text scale rather than replacing it, so someone on a tablet who has also
  /// turned system text up gets both — which is why a bigger number here would
  /// overshoot rather than help.
  final double typeScale;

  /// Widest the single column ever gets.
  ///
  /// Grows more slowly than the screen on purpose: a line of text stops being
  /// readable past roughly 75 characters however much room there is. These
  /// values hold the line length roughly constant as the type grows.
  final double contentWidth;

  /// Horizontal breathing room around a page body.
  final double pagePadding;

  static const double _mediumFrom = 600;
  static const double _expandedFrom = 840;

  static LayoutSize fromShortestSide(double shortestSide) {
    if (shortestSide >= _expandedFrom) return LayoutSize.expanded;
    if (shortestSide >= _mediumFrom) return LayoutSize.medium;
    return LayoutSize.compact;
  }

  static LayoutSize of(BuildContext context) =>
      fromShortestSide(MediaQuery.sizeOf(context).shortestSide);

  bool get isCompact => this == LayoutSize.compact;

  /// Anything with tablet-class room.
  bool get isTablet => this != LayoutSize.compact;
}
