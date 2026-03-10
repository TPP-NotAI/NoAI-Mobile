import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/platform_config_provider.dart';

/// Displays the platform logo from [PlatformConfigProvider].
/// Falls back to [fallbackIcon] when no logo URL is configured.
class AppLogo extends StatelessWidget {
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;
  final BoxDecoration? containerDecoration;

  const AppLogo({
    super.key,
    this.size = 64,
    this.fallbackIcon = Icons.fingerprint,
    this.fallbackIconColor,
    this.containerDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = context.watch<PlatformConfigProvider>().config.platformLogoUrl;

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: Image.network(
            logoUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallback(context),
          ),
        ),
      );
    }

    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: containerDecoration,
      child: Icon(
        fallbackIcon,
        size: size * 0.5,
        color: fallbackIconColor ?? AppColors.primary,
      ),
    );
  }
}
