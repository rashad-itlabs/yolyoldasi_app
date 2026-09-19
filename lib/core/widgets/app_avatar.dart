import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';
import 'app_image.dart';

/// Circular user avatar with an initials fallback and an optional verified
/// badge.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = Sizes.avatarMd,
    this.isVerified = false,
    this.onTap,
    this.borderColor,
  });

  final String? name;
  final String? photoUrl;
  final double size;
  final bool isVerified;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // A stable colour per person makes the initials feel intentional.
    final seed = (name ?? '?').codeUnits.fold<int>(0, (a, b) => a + b);
    final hue = (seed * 47) % 360;
    final background = HSLColor.fromAHSL(
      1,
      hue.toDouble(),
      context.isDark ? 0.28 : 0.35,
      context.isDark ? 0.30 : 0.88,
    ).toColor();
    final foreground = HSLColor.fromAHSL(
      1,
      hue.toDouble(),
      0.45,
      context.isDark ? 0.85 : 0.28,
    ).toColor();

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: photoUrl == null || photoUrl!.isEmpty
          ? Text(
              context.fmt.initials(name),
              style: context.text.titleMedium?.copyWith(
                color: foreground,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            )
          : AppImage(
              url: photoUrl,
              width: size,
              height: size,
              placeholder: ColoredBox(color: background),
            ),
    );

    if (isVerified) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surfaceElevated,
              ),
              child: Icon(
                Icons.verified_rounded,
                size: (size * 0.32).clamp(14, 22),
                color: context.colors.primary,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
