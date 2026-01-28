import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

/// Platform-adaptive scaffold that uses Material or Cupertino based on platform
class AdaptiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool extendBody;

  const AdaptiveScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return CupertinoPageScaffold(
        navigationBar: appBar != null && appBar is AdaptiveAppBar
            ? (appBar as AdaptiveAppBar).buildCupertinoBar(context)
            : null,
        backgroundColor:
            backgroundColor ?? CupertinoTheme.of(context).scaffoldBackgroundColor,
        child: body ?? const SizedBox.shrink(),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: extendBody,
    );
  }
}

/// Platform-adaptive app bar
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final double? elevation;
  final bool automaticallyImplyLeading;

  const AdaptiveAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.elevation,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseCupertino(context)) {
      return buildCupertinoBar(context);
    }

    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      elevation: elevation,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }

  CupertinoNavigationBar buildCupertinoBar(BuildContext context) {
    return CupertinoNavigationBar(
      middle: title,
      trailing: actions != null && actions!.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            )
          : null,
      leading: leading,
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
