import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

/// Platform-adaptive text field
class AdaptiveTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool enabled;
  final EdgeInsetsGeometry? padding;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.validator,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return _buildCupertinoTextField(context);
    }
    return _buildMaterialTextField(context);
  }

  Widget _buildCupertinoTextField(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: hintText ?? labelText,
      keyboardType: keyboardType,
      obscureText: obscureText,
      prefix: prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: prefixIcon,
            )
          : null,
      suffix: suffixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: suffixIcon,
            )
          : null,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      textInputAction: textInputAction,
      focusNode: focusNode,
      enabled: enabled,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildMaterialTextField(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      textInputAction: textInputAction,
      focusNode: focusNode,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Platform-adaptive form field (supports validation)
class AdaptiveFormField extends FormField<String> {
  AdaptiveFormField({
    super.key,
    TextEditingController? controller,
    String? hintText,
    String? labelText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
    int? maxLines = 1,
    int? minLines,
    FormFieldValidator<String>? validator,
    TextInputAction? textInputAction,
    FocusNode? focusNode,
    bool enabled = true,
    EdgeInsetsGeometry? padding,
    String? initialValue,
    ValueChanged<String>? onChanged,
  }) : super(
          validator: validator,
          initialValue: controller?.text ?? initialValue ?? '',
          builder: (FormFieldState<String> field) {
            final effectiveController = controller ?? TextEditingController(text: field.value);

            void onChangedHandler(String value) {
              field.didChange(value);
              onChanged?.call(value);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveTextField(
                  controller: effectiveController,
                  hintText: hintText,
                  labelText: labelText,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  prefixIcon: prefixIcon,
                  suffixIcon: suffixIcon,
                  maxLines: maxLines,
                  minLines: minLines,
                  onChanged: onChangedHandler,
                  textInputAction: textInputAction,
                  focusNode: focusNode,
                  enabled: enabled,
                  padding: padding,
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Text(
                      field.errorText!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
}
