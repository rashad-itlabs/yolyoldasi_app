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
    this.maxWidth = Sizes.maxContentWidth,
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
  final double maxWidth;
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
                  actions: actions,
                  leading: leading,
                  automaticallyImplyLeading: showBackButton,
                  bottom: appBarBottom,
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
                  constraints: BoxConstraints(maxWidth: maxWidth),
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
