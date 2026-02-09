import 'package:flutter/material.dart';
import '../config/app_spacing.dart';
import '../config/app_typography.dart';
import '../utils/responsive_extensions.dart';

class StoryCard extends StatelessWidget {
  final String username;
  final String avatar;
  final String? storyPreviewUrl;
  final bool isCurrentUser;
  final bool isViewed;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const StoryCard({
    super.key,
    required this.username,
    required this.avatar,
    this.storyPreviewUrl,
    this.isCurrentUser = false,
    this.isViewed = false,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80.responsive(context, min: 70, max: 90),
        margin: EdgeInsets.only(right: AppSpacing.standard.responsive(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                // Avatar with gradient border
                Container(
                  width: 64.responsive(context, min: 56, max: 72),
                  height: 64.responsive(context, min: 56, max: 72),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isCurrentUser || !isViewed
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF6366F1), // primary-ish
                              Color(0xFF3B82F6),
                              Color(0xFF8B5CF6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: isCurrentUser || !isViewed
                        ? null
                        : Border.all(color: colors.outlineVariant, width: 2),
                    boxShadow: isCurrentUser || !isViewed
                        ? [
                            BoxShadow(
                              color: colors.primary.withOpacity(0.25),
                              blurRadius: 8.responsive(context),
                              offset: Offset(0, 2.responsive(context)),
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(2.5.responsive(context)),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surface,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2.5.responsive(context)),
                        child: ClipOval(
                          child: Image.network(
                            storyPreviewUrl?.isNotEmpty == true
                                ? storyPreviewUrl!
                                : avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colors.surfaceVariant,
                                child: Icon(
                                  Icons.person,
                                  color: colors.onSurfaceVariant,
                                  size: AppTypography.responsiveIconSize(
                                    context,
                                    28,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Add button for current user
                if (isCurrentUser)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAddTap ?? onTap,
                      child: Container(
                        width: 22.responsive(context, min: 18, max: 26),
                        height: 22.responsive(context, min: 18, max: 26),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.add,
                          color: colors.onPrimary,
                          size: AppTypography.responsiveIconSize(context, 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppSpacing.small.responsive(context)),

            // Username
            Text(
              isCurrentUser ? 'Your Story' : username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: AppTypography.responsiveFontSize(context, 11),
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
