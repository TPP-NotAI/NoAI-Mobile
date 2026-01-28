import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

enum AdaptiveButtonType { filled, elevated, text, outlined }

/// Platform-adaptive button that uses Material or Cupertino based on platform
class AdaptiveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final AdaptiveButtonType type;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.type = AdaptiveButtonType.filled,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
  });

  const AdaptiveButton.filled({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
  }) : type = AdaptiveButtonType.filled;

  const AdaptiveButton.text({
    super.key,
    required this.onPressed,
    required this.child,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
  })  : type = AdaptiveButtonType.text,
        backgroundColor = null;

  const AdaptiveButton.outlined({
    super.key,
    required this.onPressed,
    required this.child,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
  })  : type = AdaptiveButtonType.outlined,
        backgroundColor = null;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return _buildCupertinoButton(context);
    }
    return _buildMaterialButton(context);
  }

  Widget _buildCupertinoButton(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    switch (type) {
      case AdaptiveButtonType.filled:
      case AdaptiveButtonType.elevated:
        return CupertinoButton.filled(
          onPressed: onPressed,
          padding: padding,
          borderRadius: BorderRadius.circular(borderRadius ?? 12.0),
          child: DefaultTextStyle(
            style: TextStyle(color: foregroundColor ?? CupertinoColors.white),
            child: child,
          ),
        );
      case AdaptiveButtonType.text:
        return CupertinoButton(
          onPressed: onPressed,
          padding: padding,
          child: DefaultTextStyle(
            style: TextStyle(
              color: foregroundColor ?? primaryColor,
            ),
            child: child,
          ),
        );
      case AdaptiveButtonType.outlined:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: foregroundColor ?? primaryColor,
            ),
            borderRadius: BorderRadius.circular(borderRadius ?? 12.0),
          ),
          child: CupertinoButton(
            onPressed: onPressed,
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DefaultTextStyle(
              style: TextStyle(
                color: foregroundColor ?? primaryColor,
              ),
              child: child,
            ),
          ),
        );
    }
  }

  Widget _buildMaterialButton(BuildContext context) {
    final buttonStyle = ButtonStyle(
      backgroundColor:
          backgroundColor != null ? WidgetStateProperty.all(backgroundColor) : null,
      foregroundColor:
          foregroundColor != null ? WidgetStateProperty.all(foregroundColor) : null,
      padding: padding != null ? WidgetStateProperty.all(padding) : null,
      shape: borderRadius != null
          ? WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius!),
              ),
            )
          : null,
    );

    switch (type) {
      case AdaptiveButtonType.filled:
        return FilledButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: child,
        );
      case AdaptiveButtonType.elevated:
        return ElevatedButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: child,
        );
      case AdaptiveButtonType.text:
        return TextButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: child,
        );
      case AdaptiveButtonType.outlined:
        return OutlinedButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: child,
        );
    }
  }
}

/// Icon button that adapts to platform
class AdaptiveIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? color;

  const AdaptiveIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: IconTheme(
          data: IconThemeData(color: color ?? CupertinoTheme.of(context).primaryColor),
          child: icon,
        ),
      );
    }

    return IconButton(
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      color: color,
    );
  }
}
