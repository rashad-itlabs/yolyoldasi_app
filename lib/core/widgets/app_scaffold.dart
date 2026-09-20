import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

/// Page wrapper that keeps content readable on tablets and the web build by
/// capping the column width, and standardises the app bar treatment.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.bottomBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.showBackButton = true,
    this.centerTitle = false,
    this.appBarBottom,
    this.maxWidth,
    this.constrainWidth = true,
    this.resizeToAvoidBottomInset = true,
    this.extendBodyBehindAppBar = false,
    this.appBar,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool showBackButton;
  final bool centerTitle;
  final PreferredSizeWidget? appBarBottom;

  /// Overrides the column width. Null takes the one for this screen size —
  /// which is what almost every page wants, and what makes a tablet show a
  /// wider column rather than a phone-width one marooned in the middle.
  final double? maxWidth;

  final bool constrainWidth;
  final bool resizeToAvoidBottomInset;
  final bool extendBodyBehindAppBar;

  /// Replaces the generated app bar entirely.
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final hasAppBar =
        appBar != null ||
        title != null ||
        titleWidget != null ||
        (actions?.isNotEmpty ?? false);

    final columnWidth = maxWidth ?? context.contentMaxWidth;

    // On a tablet the body is a centred column, but the app bar is not — it
    // spans the screen. Without this, the title sits against the left edge
    // while the content it names starts 240pt further in, and the tab bar
    // stretches to a width nothing below it shares. The bar keeps its
    // full-width surface; only its contents move inward to meet the column.
    final sideInset = constrainWidth
        ? ((context.screenWidth - columnWidth) / 2).clamp(0.0, double.infinity)
        : 0.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar:
          appBar ??
          (hasAppBar
              ? AppBar(
                  title: titleWidget ?? (title == null ? null : Text(title!)),
                  centerTitle: centerTitle,
                  // `titleSpacing` is the gap before the title when there is no
                  // leading widget, which is the case on every top-level tab.
                  titleSpacing: sideInset == 0 ? null : sideInset + Gap.lg,
                  actions: actions == null
                      ? null
                      : [
                          ...actions!,
                          if (sideInset > 0) SizedBox(width: sideInset),
                        ],
                  leading: leading,
                  automaticallyImplyLeading: showBackButton,
                  bottom: appBarBottom == null || sideInset == 0
                      ? appBarBottom
                      : _InsetBottom(inset: sideInset, child: appBarBottom!),
                )
              : null),
      // An AppBar supplies the status-bar inset; without one the body has to
      // ask for it, or the first line of content sits under the notch.
      body: SafeArea(
        top: !hasAppBar,
        bottom: false,
        child: constrainWidth
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: columnWidth),
                  child: body,
                ),
              )
            : body,
      ),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Pads an app bar's `bottom` — a tab bar, usually — in from the screen edges
/// so it lines up with the content column instead of stretching past it.
class _InsetBottom extends StatelessWidget implements PreferredSizeWidget {
  const _InsetBottom({required this.inset, required this.child});

  final double inset;
  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.symmetric(horizontal: inset), child: child);
}

/// Standard page padding for scrollable bodies.
class PagePadding extends StatelessWidget {
  const PagePadding({
    super.key,
    required this.child,
    this.top = Gap.lg,
    this.bottom = Gap.xxxl,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.page, top, Gap.page, bottom),
      child: child,
    );
  }
}

/// Dismisses the keyboard when the user taps outside a field.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.hideKeyboard,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
