import 'package:flutter/widgets.dart';

/// 4pt spacing scale. Use these instead of magic numbers so that rhythm stays
/// consistent across every screen.
abstract final class Gap {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// Horizontal padding used by virtually every page body.
  static const double page = 20;
}

/// Pre-built [SizedBox]es – `const` and cheap, keeps build methods readable.
abstract final class VGap {
  static const Widget xs = SizedBox(height: Gap.xs);
  static const Widget sm = SizedBox(height: Gap.sm);
  static const Widget md = SizedBox(height: Gap.md);
  static const Widget lg = SizedBox(height: Gap.lg);
  static const Widget xl = SizedBox(height: Gap.xl);
  static const Widget xxl = SizedBox(height: Gap.xxl);
  static const Widget xxxl = SizedBox(height: Gap.xxxl);
  static const Widget huge = SizedBox(height: Gap.huge);
  static const Widget giant = SizedBox(height: Gap.giant);
}

abstract final class HGap {
  static const Widget xs = SizedBox(width: Gap.xs);
  static const Widget sm = SizedBox(width: Gap.sm);
  static const Widget md = SizedBox(width: Gap.md);
  static const Widget lg = SizedBox(width: Gap.lg);
  static const Widget xl = SizedBox(width: Gap.xl);
}

abstract final class Radii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}

/// Motion tokens. Durations stay short — this is a utility app, not a showcase.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 480);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeOutQuad;
  static const Curve spring = Curves.easeOutBack;
}

abstract final class Sizes {
  static const double buttonHeight = 54;
  static const double buttonHeightCompact = 44;
  static const double inputHeight = 56;
  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 64;
  static const double avatarXl = 96;
  static const double icon = 22;
  static const double navBarHeight = 66;

  /// Widest a content column ever gets — keeps the admin web build readable.
  static const double maxContentWidth = 560;
  static const double maxWideContentWidth = 1180;
}
