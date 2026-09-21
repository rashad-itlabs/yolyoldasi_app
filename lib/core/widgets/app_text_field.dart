import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

/// Label above a form control: the name, plus an "optional" marker.
///
/// Shared so a hand-built control (a chip group, a picker) carries exactly the
/// same label treatment as [AppTextField].
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Both children are flexible, and neither may be dropped.
    //
    // A plain `Row` overflowed wherever a field is narrower than its own label
    // — two fields side by side on the vehicle form, and anything at all at a
    // large accessibility text scale. The label is the only thing telling the
    // user what the box is for, so it shrinks and ellipsises rather than
    // spilling off the edge.
    //
    // `Flexible` rather than `Expanded`: a short label should still sit next to
    // its "· optional" marker instead of being pushed apart by empty space.
    return Row(
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Labelled text field.
///
/// The label sits *above* the box rather than floating inside it — with three
/// languages in play, floating labels clip far too often.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.autofillHints,
    this.isRequired = false,
    this.counterText,
    this.textCapitalization = TextCapitalization.none,
    this.showCounter = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final bool isRequired;
  final String? counterText;
  final TextCapitalization textCapitalization;

  /// Shows a live `used/limit` counter. Only meaningful with [maxLength].
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          FieldLabel(text: label!, isRequired: isRequired),
          VGap.sm,
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTap: onTap,
          autofillHints: autofillHints,
          style: context.text.bodyLarge,
          cursorColor: context.colors.primary,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: errorText == null ? helper : null,
            counterText: counterText ?? (maxLength == null ? null : ''),
            counter: showCounter && maxLength != null
                ? _CharacterCounter(
                    controller: controller,
                    maxLength: maxLength!,
                  )
                : null,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: enabled
                ? (context.isDark
                      ? context.colors.surfaceContainer
                      : Colors.white)
                : palette.surfaceSunken,
          ),
        ),
      ],
    );
  }
}

/// Live `used/limit` readout that only draws attention near the cap.
class _CharacterCounter extends StatelessWidget {
  const _CharacterCounter({required this.controller, required this.maxLength});

  final TextEditingController? controller;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (controller == null) return const SizedBox.shrink();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller!,
      builder: (context, value, _) {
        final used = value.text.runes.length;
        final nearLimit = used > maxLength * 0.8;
        return Text(
          '$used/$maxLength',
          style: context.text.labelSmall?.copyWith(
            color: nearLimit ? palette.warning : palette.textTertiary,
            fontWeight: FontWeight.w400,
          ),
        );
      },
    );
  }
}

/// A field that opens a picker instead of a keyboard (city, date, time).
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.onTap,
    this.label,
    this.value,
    this.placeholder,
    this.icon,
    this.errorText,
    this.trailing,
    this.isRequired = true,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final String? label;
  final String? value;
  final String? placeholder;
  final IconData? icon;
  final String? errorText;
  final Widget? trailing;
  final bool isRequired;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasValue = value != null && value!.isNotEmpty;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!,
                style: context.text.labelMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              if (!isRequired) ...[
                HGap.xs,
                Text(
                  '· ${context.l10n.optional}',
                  style: context.text.labelSmall?.copyWith(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
          VGap.sm,
        ],
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: Radii.mdAll,
            child: Container(
              height: Sizes.inputHeight,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              decoration: BoxDecoration(
                color: enabled
                    ? (context.isDark
                          ? context.colors.surfaceContainer
                          : Colors.white)
                    : palette.surfaceSunken,
                borderRadius: Radii.mdAll,
                border: Border.all(
                  color: hasError ? context.colors.error : palette.border,
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: palette.textSecondary),
                    HGap.md,
                  ],
                  Expanded(
                    child: Text(
                      hasValue ? value! : (placeholder ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge?.copyWith(
                        color: hasValue
                            ? palette.textPrimary
                            : palette.textTertiary,
                      ),
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: palette.textTertiary,
                      ),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...[
          VGap.xs,
          Padding(
            padding: const EdgeInsets.only(left: Gap.md),
            child: Text(
              errorText!,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Formatter that applies the local mobile-number mask as the user types.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 9 ? digits.substring(0, 9) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(capped[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Uppercases and dashes an Azerbaijani plate as it is typed: `10-AA-123`.
class PlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^0-9A-Z]'),
      '',
    );
    final capped = cleaned.length > 7 ? cleaned.substring(0, 7) : cleaned;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 2 || i == 4) buffer.write('-');
      buffer.write(capped[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
