import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// Wraps [child] with a subtle press-down scale.
///
/// Used on cards and tiles where a full ink splash would be too loud but some
/// physical feedback is still wanted.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.borderRadius = Radii.lgAll,
    this.enableFeedback = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final BorderRadius borderRadius;
  final bool enableFeedback;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: Motion.instant,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}
