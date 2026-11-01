import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../app_update/presentation/widgets/optional_update_gate.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../bloc/badges/badges_bloc.dart';

/// Bottom-navigation host for the four main tabs.
///
/// The same four branches serve both modes; only the labels change, which
/// keeps navigation state intact when the user flips between driver and
/// passenger. A driver also gets the publish button raised out of the middle
/// of the dock — publishing is what driver mode is for, so it is never more
/// than one tap away from any tab.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The soft update prompt, if one is owed. Here rather than in
      // `AppStartup` because a modal sheet needs a Navigator above it, and
      // this is the first screen worth interrupting anyway.
      body: OptionalUpdateGate(child: navigationShell),
      bottomNavigationBar: _Dock(navigationShell: navigationShell),
    );
  }
}

/// The floating dock: four tabs in a pill, with the publish button rising out
/// of its middle in driver mode.
///
/// It floats over the page colour rather than spanning the screen, but the
/// body is *not* extended underneath it. Most lists in the app pad their last
/// row explicitly instead of reading `MediaQuery`, and a body drawn beneath
/// the dock would leave that row behind it with nowhere left to scroll.
class _Dock extends StatelessWidget {
  const _Dock({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Past this the four tabs drift so far apart that the dock stops reading
  /// as one control — a tablet gets a dock, not a toolbar.
  static const double _maxWidth = 520;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDriver = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.isDriverMode,
    );
    // A signed-out visitor is allowed to browse (API.md §18), so the shell is
    // on screen without an account. The other three tabs have nothing to show
    // them — they are all `/me`-shaped — so tapping one is read as "I want in".
    final isGuest = context.select<SessionBloc, bool>(
      (bloc) => bloc.state.user == null,
    );
    final messageBadge = context.select<BadgesBloc, String?>(
      (bloc) => bloc.state.messageBadge,
    );

    // Tucked into the home-indicator strip rather than stacked on top of it:
    // the full inset would leave the dock hovering a thumb's width too high.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottom = math.max(Gap.md, bottomInset - Gap.md);

    return MediaQuery.withClampedTextScaling(
      // Labels in a fixed-height dock cannot grow without limit; past this
      // they would clip. The pages above still scale fully.
      maxScaleFactor: 1.3,
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, bottom),
        child: Center(
          // `heightFactor: 1` is load-bearing: without it the Center takes
          // every pixel of height the Scaffold offers, and the body is
          // squeezed to nothing.
          heightFactor: 1.6,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.min(context.contentMaxWidth, _maxWidth),
            ),
            child: _DockBar(
              selectedIndex: navigationShell.currentIndex,
              showPublish: isDriver,
              color: Colors.green,
              publishLabel: l10n.publishRideShort,
              onPublish: () => context.push(Routes.publishRide),
              onSelected: (index) {
                if (isGuest && index != 0) {
                  context.push(Routes.login);
                  return;
                }

                navigationShell.goBranch(
                  index,
                  // Tapping the active tab pops it back to its root.
                  initialLocation: index == navigationShell.currentIndex,
                );
                // The counts have no push channel yet (API.md §13), so moving
                // between tabs is the app's best cue to re-read them.
                context.read<BadgesBloc>().add(const BadgesRefreshed());
              },
              tabs: [
                _TabSpec(
                  icon: 'assets/icon/taxi.png',
                  label: isDriver ? l10n.navRides : l10n.navSearch,
                ),
                _TabSpec(
                  icon: 'assets/icon/traveling.png',
                  label: isDriver ? l10n.navRequests : l10n.navBookings,
                ),
                _TabSpec(
                  icon: 'assets/icon/chat.png',
                  label: l10n.navChat,
                  badge: messageBadge,
                ),
                _TabSpec(icon: 'assets/icon/user.png', label: l10n.navProfile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab, as the dock draws it.
class _TabSpec {
  const _TabSpec({required this.icon, required this.label, this.badge});

  /// Asset path of a black silhouette on transparency. There is one image per
  /// tab rather than an outlined/filled pair: the dock tints it, and the
  /// colour is what tells the selected tab apart.
  final String icon;
  final String label;

  /// Already capped at "99+" by [BadgesState]; null hides the pill.
  final String? badge;
}

/// The dock itself: surface, the sliding indicator, the tabs, and the gap the
/// publish button opens in the middle.
///
/// Every position is derived from one value, [_DockBarState._position] — a
/// fractional tab index — rather than animated in pixels. The geometry moves
/// under the indicator while driver mode opens the middle gap, and an
/// indicator animating towards a pixel target would chase a moving one.
class _DockBar extends StatefulWidget {
  const _DockBar({
    required this.tabs,
    required this.selectedIndex,
    required this.showPublish,
    required this.publishLabel,
    required this.onSelected,
    required this.onPublish,
    required this.color,
  });

  final List<_TabSpec> tabs;
  final int selectedIndex;
  final bool showPublish;
  final String publishLabel;
  final ValueChanged<int> onSelected;
  final VoidCallback onPublish;
  final Color color;

  static const double height = 64;

  /// Width the middle gap opens to in driver mode.
  static const double gapWidth = 76;

  static const double indicatorWidth = 56;
  static const double indicatorHeight = 32;

  /// Space between the indicator and the label under it.
  static const double labelGap = 2;

  /// A fixed box for the label, with the text centred in it. Fixed so that
  /// where the label lands does not depend on the font's own line height,
  /// which differs between Inter and the platform fallback.
  static const double labelHeight = 16;

  /// Where the icon-and-label block starts: the vertical middle of the dock,
  /// lifted by [_opticalLift]. Everything that has to line up — the sliding
  /// indicator, every tab, the publish label — is placed from this one number.
  static const double contentTop =
      (height - indicatorHeight - labelGap - labelHeight) / 2 - _opticalLift;

  /// The labels are lower-case words whose ink sits in the lower half of
  /// their box, so a block centred by its boxes reads about two points low.
  /// Measured on a render: with no lift the ink had 13.7pt above it and
  /// 10pt below.
  static const double _opticalLift = 1.5;

  /// How much wider the indicator stretches mid-flight — the "liquid" part.
  static const double indicatorStretch = 26;

  @override
  State<_DockBar> createState() => _DockBarState();
}

class _DockBarState extends State<_DockBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: Motion.normal,
  )..value = 1;

  late double _from = widget.selectedIndex.toDouble();
  late double _to = _from;

  /// The indicator's place as a fractional tab index.
  double get _position =>
      lerpDouble(_from, _to, Motion.emphasized.transform(_move.value))!;

  @override
  void didUpdateWidget(_DockBar old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex != old.selectedIndex) {
      // From wherever it is now, so a second tap mid-flight turns it round
      // smoothly instead of snapping back to the old tab first.
      _from = _position;
      _to = widget.selectedIndex.toDouble();
      _move.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.tabs.length;
    final half = count ~/ 2;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.showPublish ? 1 : 0),
      duration: Motion.slow,
      curve: Motion.emphasized,
      builder: (context, open, _) {
        final raise = _PublishButton.rise * open;

        return SizedBox(
          height: _DockBar.height + raise,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final gap = _DockBar.gapWidth * open;
              final slot = (width - gap) / count;

              double slotCenter(int i) =>
                  slot * (i + 0.5) + (i >= half ? gap : 0);
              double centerAt(double index) {
                final lower = index.floor().clamp(0, count - 1);
                final upper = index.ceil().clamp(0, count - 1);
                return lerpDouble(
                  slotCenter(lower),
                  slotCenter(upper),
                  index - lower,
                )!;
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ------------------------------------------------ surface
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _DockBar.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.surfaceElevated,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(_DockBar.height / 2),
                        ),
                        border: Border.all(
                          color: palette.border.withValues(alpha: 0.7),
                          width: 0.8,
                        ),
                        boxShadow: [
                          // A long soft shadow lifts the dock off the page; the
                          // tight one keeps its edge crisp. Light mode stays
                          // faint: the dock sits a few points above the screen
                          // edge, and anything heavier pools under it as a
                          // grey slab.
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.45 : 0.06,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.30 : 0.04,
                            ),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---------------------------------------------- indicator
                  AnimatedBuilder(
                    animation: _move,
                    builder: (context, _) {
                      final stretch = math.sin(math.pi * _move.value);
                      final w =
                          _DockBar.indicatorWidth +
                          _DockBar.indicatorStretch * stretch;
                      return Positioned(
                        left: centerAt(_position) - w / 2,
                        top: raise + _DockBar.contentTop,
                        width: w,
                        height: _DockBar.indicatorHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.colors.primaryContainer,
                            borderRadius: Radii.pillAll,
                          ),
                        ),
                      );
                    },
                  ),

                  // --------------------------------------------------- tabs
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _DockBar.height,
                    child: Row(
                      // Every slot gets the dock's full height, so a tab's
                      // own layout decides where its content sits — not the
                      // Row centring a shorter column on top of it.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < count; i++) ...[
                          if (i == half)
                            SizedBox(
                              width: gap,
                              child: _PublishLabel(
                                label: widget.publishLabel,
                                opacity: open,
                              ),
                            ),
                          SizedBox(
                            width: slot,
                            child: _TabButton(
                              spec: widget.tabs[i],
                              selected: i == widget.selectedIndex,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.onSelected(i);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ----------------------------------------------- publish
                  if (open > 0)
                    Positioned(
                      left: width / 2 - _PublishButton.outerSize / 2,
                      top: raise - _PublishButton.rise,
                      child: IgnorePointer(
                        // Not tappable while it is still growing in or
                        // shrinking away.
                        ignoring: open < 1,
                        child: Transform.rotate(
                          angle: (1 - open) * -math.pi / 2,
                          child: Transform.scale(
                            scale: Curves.easeOutBack.transform(open),
                            child: _PublishButton(
                              label: widget.publishLabel,
                              onPressed: widget.onPublish,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// A tab: icon over label. The indicator behind it belongs to the dock, so
/// that it can slide between tabs instead of fading in place.
class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final spec = widget.spec;
    final selected = widget.selected;

    Widget icon = AnimatedSwitcher(
      duration: Motion.fast,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween(
          begin: 0.7,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Motion.spring)),
        child: FadeTransition(opacity: animation, child: child),
      ),
      // 22 rather than Material's 24: these glyphs run to the edge of their
      // canvas, where a Material icon keeps a 2pt margin inside its box.
      child: ImageIcon(
        AssetImage(spec.icon),
        key: ValueKey(selected),
        size: 22,
        color: selected ? colors.onPrimaryContainer : palette.textTertiary,
      ),
    );
    if (spec.badge != null) {
      icon = Badge(label: Text(spec.badge!), child: icon);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1,
          duration: Motion.instant,
          curve: Motion.standard,
          child: Column(
            children: [
              const SizedBox(height: _DockBar.contentTop),
              SizedBox(
                height: _DockBar.indicatorHeight,
                child: Center(child: icon),
              ),
              const SizedBox(height: _DockBar.labelGap),
              _LabelBox(
                child: AnimatedDefaultTextStyle(
                  duration: Motion.fast,
                  style: context.text.labelSmall!.copyWith(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? colors.primary : palette.textTertiary,
                    letterSpacing: 0.1,
                  ),
                  child: Text(spec.label, maxLines: 1, softWrap: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The label's fixed box: centred, and scaled down rather than clipped when a
/// long label or a large text size would not fit.
class _LabelBox extends StatelessWidget {
  const _LabelBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _DockBar.labelHeight,
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    );
  }
}

/// "Elan ver" under the publish button, on the same line as the tab labels.
///
/// The button alone is a plus sign, and a plus sign means "add something" in
/// every app; the label says what is being added. Scaled down rather than
/// clipped while the gap is still opening.
class _PublishLabel extends StatelessWidget {
  const _PublishLabel({required this.label, required this.opacity});

  final String label;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity == 0) return const SizedBox.shrink();

    return ExcludeSemantics(
      // The button itself carries the label for screen readers.
      child: Opacity(
        opacity: opacity,
        // The same stack of heights as [_TabButton], so the label lands on
        // exactly the line the tab labels sit on.
        child: Column(
          children: [
            const SizedBox(
              height:
                  _DockBar.contentTop +
                  _DockBar.indicatorHeight +
                  _DockBar.labelGap,
            ),
            _LabelBox(
              child: Text(
                label,
                maxLines: 1,
                style: context.text.labelSmall!.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textSecondary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The driver's publish button: a brand-gradient disc rising out of the dock.
///
/// The ring around it is painted in the page colour, which is what makes it
/// read as sitting in a cut-out of the dock rather than on top of it — the
/// same notch a `BottomAppBar` draws, without a custom path. A tap gives it a
/// quarter spin before the publish screen opens: a plus turned by 90° is still
/// a plus, so the motion is all feedback and no change of meaning.
class _PublishButton extends StatefulWidget {
  const _PublishButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const double size = 56;
  static const double ring = 5;
  static const double outerSize = size + ring * 2;

  /// How far the button's top rises above the dock's top edge.
  static const double rise = 27;

  @override
  State<_PublishButton> createState() => _PublishButtonState();
}

class _PublishButtonState extends State<_PublishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    _spin.forward(from: 0);
    widget.onPressed();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final gradient = palette.heroGradient;

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: Motion.instant,
            curve: Motion.standard,
            child: Container(
              width: _PublishButton.outerSize,
              height: _PublishButton.outerSize,
              padding: const EdgeInsets.all(_PublishButton.ring),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  boxShadow: [
                    // Tinted with the gradient's own deep end, so the glow
                    // reads as light from the button rather than a grey smudge.
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // A soft highlight in the top-left: the difference between
                    // a flat disc and something that looks pressable.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.45, -0.55),
                            radius: 0.75,
                            colors: [
                              Colors.white.withValues(alpha: 0.30),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.25).animate(
                        CurvedAnimation(parent: _spin, curve: Motion.spring),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
