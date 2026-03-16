import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/app_typography.dart';
import '../utils/responsive_extensions.dart';

class StoryCard extends StatelessWidget {
  final String username;
  final String avatar;
  final String? storyPreviewUrl;
  final String? backgroundColor;
  final bool isTextStory;
  final bool isCurrentUser;
  final bool isViewed;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const StoryCard({
    super.key,
    required this.username,
    required this.avatar,
    this.storyPreviewUrl,
    this.backgroundColor,
    this.isTextStory = false,
    this.isCurrentUser = false,
    this.isViewed = false,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatarSize = 62.responsive(context, min: 54, max: 70);
    final cardWidth = 72.responsive(context, min: 64, max: 82);

    // Ring: gold gradient for unviewed/own, muted outline for viewed
    final hasRing = isCurrentUser || !isViewed;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Outer ring
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasRing
                        ? LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.65),
                              const Color(0xFFBB8620),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: hasRing
                        ? null
                        : Border.all(
                            color: colors.outlineVariant,
                            width: 1.5,
                          ),
                  ),
                  // White gap between ring and avatar
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surface,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: ClipOval(
                          child: isTextStory
                              ? _buildTextStoryPreview(colors)
                              : Image.network(
                                  storyPreviewUrl?.isNotEmpty == true
                                      ? storyPreviewUrl!
                                      : avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: colors.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.person,
                                      color: colors.onSurfaceVariant,
                                      size: AppTypography.responsiveIconSize(
                                        context,
                                        26,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Add badge for current user
                if (isCurrentUser)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAddTap ?? onTap,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.black,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: AppSpacing.small.responsive(context)),

            // Username label
            Text(
              isCurrentUser ? 'Your Story' : username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: AppTypography.responsiveFontSize(context, 11),
                fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.w500,
                color: colors.onSurface,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextStoryPreview(ColorScheme colors) {
    Color bgColor = AppColors.primary;
    if (backgroundColor != null && backgroundColor!.isNotEmpty) {
      try {
        final colorStr = backgroundColor!.replaceFirst('#', '');
        bgColor = Color(int.parse('FF$colorStr', radix: 16));
      } catch (_) {}
    }

    return Container(
      color: bgColor,
      child: Center(
        child: Icon(
          Icons.text_fields,
          color: Colors.white.withValues(alpha: 0.85),
          size: 22,
        ),
      ),
    );
  }
}
