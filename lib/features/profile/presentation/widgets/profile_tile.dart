import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';

/// Settings-style row: icon, label, optional value/badge, chevron.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.badge,
    this.isDestructive = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Shown between the label and the chevron — a status chip, a count, …
  final Widget? badge;

  final bool isDestructive;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = isDestructive ? palette.danger : palette.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: Radii.smAll,
                color: isDestructive
                    ? palette.dangerContainer
                    : palette.surfaceSunken,
              ),
              child: Icon(
                icon,
                size: 17,
                color:
                    iconColor ??
                    (isDestructive ? palette.danger : palette.textSecondary),
              ),
            ),
            HGap.lg,
            Expanded(
              child: Text(
                label,
                style: context.text.bodyLarge?.copyWith(
                  color: foreground,
                  fontSize: 14,
                ),
              ),
            ),
            if (badge != null) ...[badge!, HGap.sm],
            if (value != null) ...[
              Text(
                value!,
                style: context.text.bodyMedium?.copyWith(
                  color: palette.textTertiary,
                  fontSize: 12,
                ),
              ),
              HGap.sm,
            ],
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: palette.textTertiary,
                      )),
          ],
        ),
      ),
    );
  }
}

/// Groups [ProfileTile]s into one bordered card with dividers between rows.
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xs, 0, 0, Gap.sm),
            child: Text(
              title!,
              style: context.text.labelSmall?.copyWith(
                color: palette.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: Radii.lgAll,
            border: Border.all(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 64),
                    child: Divider(height: 1, color: palette.border),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
