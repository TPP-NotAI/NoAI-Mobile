import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

/// Platform-adaptive bottom navigation bar
class AdaptiveNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationDestination> destinations;
  final Color? backgroundColor;

  const AdaptiveNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return CupertinoTabBar(
        currentIndex: currentIndex,
        onTap: onDestinationSelected,
        backgroundColor: backgroundColor,
        items: destinations
            .map((dest) => BottomNavigationBarItem(
                  icon: dest.icon,
                  activeIcon: dest.selectedIcon ?? dest.icon,
                  label: dest.label,
                ))
            .toList(),
      );
    }

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations
          .map((dest) => NavigationDestination(
                icon: dest.icon,
                selectedIcon: dest.selectedIcon,
                label: dest.label,
              ))
          .toList(),
      backgroundColor: backgroundColor,
    );
  }
}

/// Wrapper for navigation destination items
class AdaptiveNavigationDestination {
  final Widget icon;
  final Widget? selectedIcon;
  final String label;

  const AdaptiveNavigationDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

/// Platform-adaptive progress indicator
class AdaptiveProgressIndicator extends StatelessWidget {
  final double? value;
  final Color? color;

  const AdaptiveProgressIndicator({
    super.key,
    this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return CupertinoActivityIndicator(
        color: color,
      );
    }

    return CircularProgressIndicator(
      value: value,
      color: color,
    );
  }
}

/// Platform-adaptive switch
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      );
    }

    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: activeColor != null
          ? WidgetStateProperty.all(activeColor)
          : null,
    );
  }
}

/// Platform-adaptive alert dialog
class AdaptiveAlertDialog extends StatelessWidget {
  final String? title;
  final String? content;
  final List<AdaptiveDialogAction> actions;

  const AdaptiveAlertDialog({
    super.key,
    this.title,
    this.content,
    required this.actions,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? content,
    required List<AdaptiveDialogAction> actions,
  }) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return showCupertinoDialog<T>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: title != null ? Text(title) : null,
          content: content != null ? Text(content) : null,
          actions: actions
              .map((action) => CupertinoDialogAction(
                    onPressed: action.onPressed,
                    isDefaultAction: action.isDefaultAction,
                    isDestructiveAction: action.isDestructive,
                    child: Text(action.label),
                  ))
              .toList(),
        ),
      );
    }

    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: title != null ? Text(title) : null,
        content: content != null ? Text(content) : null,
        actions: actions
            .map((action) => TextButton(
                  onPressed: action.onPressed,
                  child: Text(
                    action.label,
                    style: TextStyle(
                      color: action.isDestructive ? Colors.red : null,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return CupertinoAlertDialog(
        title: title != null ? Text(title!) : null,
        content: content != null ? Text(content!) : null,
        actions: actions
            .map((action) => CupertinoDialogAction(
                  onPressed: action.onPressed,
                  isDefaultAction: action.isDefaultAction,
                  isDestructiveAction: action.isDestructive,
                  child: Text(action.label),
                ))
            .toList(),
      );
    }

    return AlertDialog(
      title: title != null ? Text(title!) : null,
      content: content != null ? Text(content!) : null,
      actions: actions
          .map((action) => TextButton(
                onPressed: action.onPressed,
                child: Text(
                  action.label,
                  style: TextStyle(
                    color: action.isDestructive ? Colors.red : null,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class AdaptiveDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isDefaultAction;
  final bool isDestructive;

  const AdaptiveDialogAction({
    required this.label,
    this.onPressed,
    this.isDefaultAction = false,
    this.isDestructive = false,
  });
}
