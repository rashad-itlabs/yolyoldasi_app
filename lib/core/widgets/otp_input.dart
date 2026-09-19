import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

/// Six-box SMS code field.
///
/// A single hidden [EditableText] owns the value, so paste, autofill and the
/// Android SMS auto-retrieval all work; the boxes are pure presentation.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.onChanged,
    this.onCompleted,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final int length;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String get _value => _controller.text;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChange);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChange)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {});
    widget.onChanged(_value);
    if (_value.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted?.call(_value);
    }
  }

  /// Lets the page clear the field after a wrong code.
  void clear() => _controller.clear();

  /// Places a code into the field from outside — used by the banner that shows
  /// the code while the API still echoes it back. Runs through the controller,
  /// so it completes exactly as typing would.
  void fill(String value) => _controller.text = value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;
    final focused = _focusNode.hasFocus;

    return Stack(
      children: [
        // The real input, kept invisible but focusable.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              showCursor: false,
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: widget.enabled ? _focusNode.requestFocus : null,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              final filled = index < _value.length;
              final isActive = focused && index == _value.length;

              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.length - 1 ? 0 : Gap.sm,
                ),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  curve: Motion.standard,
                  width: 48,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? colors.surfaceContainer
                        : Colors.white,
                    borderRadius: Radii.mdAll,
                    border: Border.all(
                      color: widget.hasError
                          ? colors.error
                          : isActive
                          ? colors.primary
                          : filled
                          ? palette.borderStrong
                          : palette.border,
                      width: isActive || widget.hasError ? 1.8 : 1,
                    ),
                  ),
                  child: filled
                      ? Text(
                          _value[index],
                          style: context.text.headlineSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        )
                      : isActive
                      ? Container(
                          width: 2,
                          height: 22,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: Radii.pillAll,
                          ),
                        )
                      : null,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
