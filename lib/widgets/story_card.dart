import 'package:flutter/material.dart';

class StoryCard extends StatelessWidget {
  final String username;
  final String avatar;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const StoryCard({
    super.key,
    required this.username,
    required this.avatar,
    this.isCurrentUser = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                // Avatar with gradient border
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366F1), // primary-ish
                        Color(0xFF3B82F6),
                        Color(0xFF8B5CF6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surface,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: ClipOval(
                          child: Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colors.surfaceVariant,
                                child: Icon(
                                  Icons.person,
                                  color: colors.onSurfaceVariant,
                                  size: 28,
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
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                        border: Border.all(color: colors.surface, width: 2),
                      ),
                      child: Icon(Icons.add, color: colors.onPrimary, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Username
            Text(
              isCurrentUser ? 'Your Story' : username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
