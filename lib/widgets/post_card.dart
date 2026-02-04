import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/user_provider.dart';

import '../models/post.dart';
import '../providers/feed_provider.dart';
import '../providers/auth_provider.dart';
import '../config/supabase_config.dart';
import '../screens/bookmarks/bookmarks_screen.dart';
import '../screens/create/edit_post_screen.dart';
import '../screens/post_detail_screen.dart';
import '../utils/time_utils.dart';
import 'video_player_widget.dart';
import 'full_screen_media_viewer.dart';
import 'report_sheet.dart';
import 'shimmer_loading.dart';
import 'mention_rich_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/wallet_repository.dart';
import '../services/roocoin_service.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onTipTap;
  final VoidCallback? onProfileTap;
  final Function(String)? onHashtagTap;

  const PostCard({
    super.key,
    required this.post,
    this.onCommentTap,
    this.onTipTap,
    this.onProfileTap,
    this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.reposter != null) _RepostHeader(post: post),

            _Header(post: post, onProfileTap: onProfileTap),

            if (post.status == 'under_review')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: colors.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: colors.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This post is under review by moderators.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _MlScoreBadge(
                score: post.aiConfidenceScore,
                isModerated: post.status == 'under_review',
              ),
            ),

            if (post.isSensitive)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sensitive Content',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.error,
                            ),
                          ),
                          if (post.sensitiveReason != null)
                            Text(
                              post.sensitiveReason!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onErrorContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (post.title != null && post.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  post.title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            _Content(post: post),

            if (post.tags != null && post.tags!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: post.tags!.map((tag) {
                    return GestureDetector(
                      onTap: onHashtagTap != null
                          ? () => onHashtagTap!(tag.name)
                          : null,
                      child: Text(
                        '#${tag.name}',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            if (post.hasMedia) _MediaGridView(post: post),

            _Actions(
              post: post,
              onCommentTap: onCommentTap,
              onTipTap: onTipTap,
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── HEADER ───────────────── */

class _Header extends StatefulWidget {
  final Post post;
  final VoidCallback? onProfileTap;

  const _Header({required this.post, this.onProfileTap});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  String? _displayLocation;
  bool _isLoadingLocation = false;

  // Cache for geocoded locations to avoid repeated API calls
  static final Map<String, String> _locationCache = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  void _initLocation() {
    final location = widget.post.location;
    if (location == null || location.isEmpty) return;

    // Check if it's already a human-readable location (not coordinates)
    if (!_looksLikeCoordinates(location)) {
      _displayLocation = location;
      return;
    }

    // Check cache first
    if (_locationCache.containsKey(location)) {
      _displayLocation = _locationCache[location];
      return;
    }

    // Convert coordinates to address
    _convertCoordinatesToAddress(location);
  }

  bool _looksLikeCoordinates(String location) {
    // Check if location matches coordinate pattern like "-26.2041, 28.0473"
    final coordPattern = RegExp(r'^-?\d+\.?\d*,\s*-?\d+\.?\d*$');
    return coordPattern.hasMatch(location.trim());
  }

  Future<void> _convertCoordinatesToAddress(String coordinates) async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      final parts = coordinates.split(',').map((s) => s.trim()).toList();
      if (parts.length != 2) {
        _displayLocation = coordinates;
        return;
      }

      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);

      if (lat == null || lng == null) {
        _displayLocation = coordinates;
        return;
      }

      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final locationParts = <String>[];

        if (place.locality != null && place.locality!.isNotEmpty) {
          locationParts.add(place.locality!);
        } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          locationParts.add(place.subLocality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          locationParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          locationParts.add(place.country!);
        }

        final humanReadable = locationParts.isNotEmpty
            ? locationParts.join(', ')
            : coordinates;

        // Cache the result
        _locationCache[coordinates] = humanReadable;

        setState(() {
          _displayLocation = humanReadable;
        });
      }
    } catch (e) {
      debugPrint('Failed to geocode location: $e');
      if (mounted) {
        setState(() {
          _displayLocation = coordinates;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final post = widget.post;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onProfileTap,
            child: CircleAvatar(
              radius: 22,
              backgroundImage: post.author.avatar.isNotEmpty
                  ? NetworkImage(post.author.avatar)
                  : null,
              backgroundColor: colors.surfaceVariant,
              child: post.author.avatar.isEmpty
                  ? Icon(Icons.person, color: colors.onSurfaceVariant)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: widget.onProfileTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        post.author.displayName.isNotEmpty
                            ? post.author.displayName
                            : post.author.username,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (post.author.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 14, color: colors.primary),
                      ],
                    ],
                  ),
                  if (post.author.displayName.isNotEmpty &&
                      post.author.displayName.toLowerCase() !=
                          post.author.username.toLowerCase()) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${post.author.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        humanReadableTime(post.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      if (post.location != null &&
                          post.location!.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: _isLoadingLocation
                              ? SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                )
                              : Text(
                                  _displayLocation ?? post.location!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.more_horiz, color: colors.onSurfaceVariant),
            onPressed: () => _showPostMenu(context),
          ),
        ],
      ),
    );
  }

  void _showPostMenu(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PostMenu(post: widget.post),
    );
  }
}

/* ───────────────── REPOST HEADER ───────────────── */

class _RepostHeader extends StatelessWidget {
  final Post post;

  const _RepostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.reposter == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.repeat,
            size: 14,
            color: colors.onSurfaceVariant.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${post.reposter!.displayName.isNotEmpty ? post.reposter!.displayName : post.reposter!.username} reposted',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── ML SCORE BADGE ───────────────── */
// ... (ML Score Badge unchanged)

class _MlScoreBadge extends StatelessWidget {
  final double? score;
  final bool isModerated;

  const _MlScoreBadge({required this.score, this.isModerated = false});

  @override
  Widget build(BuildContext context) {
    final bool isPending = score == null;

    final Color badgeColor;
    final Color bgColor;
    final String label;

    if (isModerated) {
      badgeColor = const Color(0xFFF59E0B); // Amber
      bgColor = const Color(0xFF451A03);
      label = 'UNDER REVIEW';
    } else if (isPending) {
      badgeColor = const Color(0xFF9CA3AF);
      bgColor = const Color(0xFF1F2937);
      label = 'ML SCORE: PENDING';
    } else if (score! < 50) {
      badgeColor = const Color(0xFF10B981);
      bgColor = const Color(0xFF052E1C);
      label = 'ML SCORE: ${score!.toStringAsFixed(2)}% [PASS]';
    } else if (score! < 75) {
      // 50-75% is Review/Uncertain (Not hidden, but flagged as potential)
      badgeColor = const Color(0xFFF59E0B); // Amber
      bgColor = const Color(0xFF451A03);
      label = 'ML SCORE: ${score!.toStringAsFixed(2)}% [REVIEW]';
    } else {
      // 75%+ is High Probability AI
      badgeColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFF2D0F0F);
      label = 'ML SCORE: ${score!.toStringAsFixed(2)}% [AI DETECTED]';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── CONTENT ───────────────── */
// ...

class _Content extends StatefulWidget {
  final Post post;

  const _Content({required this.post});

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  bool _expanded = false;
  static const int _maxLines = 3;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final post = widget.post;

    // Don't show anything if content is empty
    if (post.content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final textStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: colors.onSurface,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textSpan = TextSpan(text: post.content, style: textStyle);
          final textPainter = TextPainter(
            text: textSpan,
            maxLines: _maxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);
          final isOverflowing = textPainter.didExceedMaxLines;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: post),
                    ),
                  );
                },
                child: _expanded || !isOverflowing
                    ? MentionRichText(
                        text: post.content,
                        style: textStyle,
                        onMentionTap: (username) =>
                            navigateToMentionedUser(context, username),
                      )
                    : MentionRichText(
                        text: post.content,
                        style: textStyle,
                        maxLines: _maxLines,
                        overflow: TextOverflow.clip,
                        onMentionTap: (username) =>
                            navigateToMentionedUser(context, username),
                      ),
              ),
              if (isOverflowing)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _expanded ? 'Show less' : '... more',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/* ───────────────── MEDIA GRID VIEW (Facebook-style) ───────────────── */

class _MediaGridView extends StatelessWidget {
  final Post post;

  const _MediaGridView({required this.post});

  List<_MediaItem> _getMediaItems() {
    final items = <_MediaItem>[];

    // Use mediaList if available
    if (post.mediaList != null && post.mediaList!.isNotEmpty) {
      for (final media in post.mediaList!) {
        String url = media.storagePath;
        if (!url.startsWith('http')) {
          url =
              '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/$url';
        }
        items.add(_MediaItem(url: url, isVideo: media.mediaType == 'video'));
      }
    } else if (post.mediaUrl != null) {
      // Fallback to single mediaUrl
      final url = post.mediaUrl!.toLowerCase();
      final isVideo =
          url.endsWith('.mp4') || url.endsWith('.mov') || url.endsWith('.avi');
      items.add(_MediaItem(url: post.mediaUrl!, isVideo: isVideo));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final mediaItems = _getMediaItems();
    if (mediaItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildMediaGrid(context, mediaItems),
      ),
    );
  }

  Widget _buildMediaGrid(BuildContext context, List<_MediaItem> items) {
    final count = items.length;

    if (count == 1) {
      return _SingleMediaView(item: items[0], post: post);
    } else if (count == 2) {
      return _TwoMediaGrid(items: items, post: post);
    } else if (count == 3) {
      return _ThreeMediaGrid(items: items, post: post);
    } else if (count == 4) {
      return _FourMediaGrid(items: items, post: post);
    } else {
      // 5+ images: show 4 with a "+N" overlay on the last one
      return _FourPlusMediaGrid(items: items, post: post);
    }
  }
}

class _MediaItem {
  final String url;
  final bool isVideo;

  _MediaItem({required this.url, this.isVideo = false});
}

/// Single media - full width
class _SingleMediaView extends StatelessWidget {
  final _MediaItem item;
  final Post post;

  const _SingleMediaView({required this.item, required this.post});

  @override
  Widget build(BuildContext context) {
    return _MediaTile(item: item, height: 300, post: post, index: 0);
  }
}

/// Two media - side by side
class _TwoMediaGrid extends StatelessWidget {
  final List<_MediaItem> items;
  final Post post;

  const _TwoMediaGrid({required this.items, required this.post});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: _MediaTile(item: items[0], post: post, index: 0),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _MediaTile(item: items[1], post: post, index: 1),
          ),
        ],
      ),
    );
  }
}

/// Three media - one large on left, two stacked on right
class _ThreeMediaGrid extends StatelessWidget {
  final List<_MediaItem> items;
  final Post post;

  const _ThreeMediaGrid({required this.items, required this.post});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _MediaTile(item: items[0], post: post, index: 0),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _MediaTile(item: items[1], post: post, index: 1),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _MediaTile(item: items[2], post: post, index: 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Four media - 2x2 grid
class _FourMediaGrid extends StatelessWidget {
  final List<_MediaItem> items;
  final Post post;

  const _FourMediaGrid({required this.items, required this.post});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaTile(item: items[0], post: post, index: 0),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _MediaTile(item: items[1], post: post, index: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaTile(item: items[2], post: post, index: 2),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _MediaTile(item: items[3], post: post, index: 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 5+ media - 2x2 grid with "+N" overlay on last tile
class _FourPlusMediaGrid extends StatelessWidget {
  final List<_MediaItem> items;
  final Post post;

  const _FourPlusMediaGrid({required this.items, required this.post});

  @override
  Widget build(BuildContext context) {
    final extraCount = items.length - 4;

    return SizedBox(
      height: 280,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaTile(item: items[0], post: post, index: 0),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _MediaTile(item: items[1], post: post, index: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaTile(item: items[2], post: post, index: 2),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _MediaTile(item: items[3], post: post, index: 3),
                      Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Center(
                          child: Text(
                            '+$extraCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual media tile (image or video thumbnail)
class _MediaTile extends StatelessWidget {
  final _MediaItem item;
  final double? height;
  final Post post;
  final int index;

  const _MediaTile({
    required this.item,
    this.height,
    required this.post,
    required this.index,
  });

  void _openFullScreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenMediaViewer(
              post: post,
              mediaUrl: item.url,
              isVideo: item.isVideo,
              heroTag: '${post.id}_$index',
              mediaList: post.mediaList,
              initialIndex: index,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isVideo)
              Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video thumbnail - could be first frame
                    VideoPlayerWidget(videoUrl: item.url),
                    // Play button overlay
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: item.url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ShimmerLoading(
                  isLoading: true,
                  child: ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: colors.surfaceVariant,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 32,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            // Verified badge on first media only if it's human certified or pass AI check
            if (index == 0 && (post.humanCertified || post.isHumanVerified))
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── ACTIONS ───────────────── */

class _Actions extends StatelessWidget {
  final Post post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onTipTap;

  const _Actions({required this.post, this.onCommentTap, this.onTipTap});

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<FeedProvider>();
    final isBookmarked = feedProvider.isBookmarked(post.id);
    final isReposted = feedProvider.isReposted(post.id);
    final repostCount = feedProvider.getRepostCount(post.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _ActionButton(
            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
            label: _format(post.likes),
            isLiked: post.isLiked,
            onTap: () => feedProvider.toggleLike(post.id),
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: _format(post.comments),
            onTap: onCommentTap,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.repeat,
            label: repostCount > 0 ? _format(repostCount) : null,
            isReposted: isReposted,
            onTap: () => _handleRepost(context, feedProvider),
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.toll,
            label: post.tips > 0 ? _format(post.tips.toInt()) : null,
            onTap: onTipTap,
          ),
          const Spacer(),
          _ActionButton(
            icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            isBookmarked: isBookmarked,
            onTap: () => _handleBookmark(context, feedProvider, isBookmarked),
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.share_outlined,
            onTap: () => _handleShare(context),
          ),
        ],
      ),
    );
  }

  void _handleRepost(BuildContext context, FeedProvider feedProvider) {
    final wasReposted = feedProvider.isReposted(post.id);
    feedProvider.toggleRepost(post.id);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            wasReposted ? 'Removed repost' : 'Reposted to your profile',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  void _handleBookmark(
    BuildContext context,
    FeedProvider feedProvider,
    bool wasBookmarked,
  ) {
    feedProvider.toggleBookmark(post.id);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            wasBookmarked ? 'Removed from bookmarks' : 'Saved to bookmarks',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: !wasBookmarked
              ? SnackBarAction(
                  label: 'VIEW',
                  textColor: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BookmarksScreen(),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
  }

  void _handleShare(BuildContext context) async {
    try {
      // Create share text
      final shareText = post.title != null && post.title!.isNotEmpty
          ? '${post.title}\n\n${post.content}\n\nShared from NOAI'
          : '${post.content}\n\nShared from NOAI';

      // Share using native share dialog
      await Share.share(
        shareText,
        subject: post.title ?? 'Check out this post on NOAI',
      );

      // Award 5 ROO to post author for the share
      if (post.authorId.isNotEmpty) {
        try {
          final walletRepo = WalletRepository();
          await walletRepo.earnRoo(
            userId: post.authorId,
            activityType: RoocoinActivityType.postShare,
            referencePostId: post.id,
          );
        } catch (e) {
          debugPrint('Error awarding share ROO: $e');
        }
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Post shared! Author earned 5 ROO 🎉'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      debugPrint('Error sharing post: $e');
    }
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

/* ───────────────── SHARED UI ───────────────── */

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isLiked;
  final bool isBookmarked;
  final bool isReposted;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isReposted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Determine color based on state
    Color iconColor;
    Color textColor;

    if (isLiked) {
      iconColor = Colors.red;
      textColor = Colors.red;
    } else if (isBookmarked) {
      iconColor = colors.primary;
      textColor = colors.primary;
    } else if (isReposted) {
      iconColor = const Color(0xFF10B981);
      textColor = const Color(0xFF10B981);
    } else {
      iconColor = colors.onSurfaceVariant;
      textColor = colors.onSurfaceVariant;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label!, style: TextStyle(fontSize: 13, color: textColor)),
            ],
          ],
        ),
      ),
    );
  }
}

/* ───────────────── POST MENU ───────────────── */

class _PostMenu extends StatelessWidget {
  final Post post;

  const _PostMenu({required this.post});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    final isAuthor = currentUserId != null && post.authorId == currentUserId;

    return Material(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isAuthor) ...[
              _MenuOption(
                icon: Icons.edit,
                label: 'Edit Post',
                onTap: () => _handleEdit(context),
              ),
              _MenuOption(
                icon: Icons.visibility_off,
                label: 'Unpublish',
                onTap: () => _handleUnpublish(context),
              ),
              _MenuOption(
                icon: Icons.delete_forever,
                label: 'Delete',
                destructive: true,
                onTap: () => _handleDelete(context),
              ),
            ] else ...[
              _MenuOption(
                icon: Icons.bookmark_border,
                label: 'Save post',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement save logic in FeedProvider
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post saved to bookmarks')),
                  );
                },
              ),
              _MenuOption(
                icon: Icons.link,
                label: 'Copy link',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement copy link logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
              ),
              _MenuOption(
                icon: Icons.report_outlined,
                label: 'Report',
                onTap: () => _handleReport(context),
              ),
              _MenuOption(
                icon: Icons.volume_off,
                label: 'Mute @${post.author.username}',
                onTap: () async {
                  final userProvider = context.read<UserProvider>();
                  final success = await userProvider.toggleMute(post.authorId);
                  if (context.mounted) {
                    if (success) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('@${post.author.username} muted.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            userProvider.error ?? 'Failed to mute user',
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
              _MenuOption(
                icon: Icons.block,
                label: 'Block @${post.author.username}',
                destructive: true,
                onTap: () async {
                  final userProvider = context.read<UserProvider>();
                  final success = await userProvider.toggleBlock(post.authorId);
                  if (context.mounted) {
                    if (success) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('@${post.author.username} blocked.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            userProvider.error ?? 'Failed to block user',
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleEdit(BuildContext context) {
    Navigator.pop(context); // Close menu
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
    );
  }

  void _handleUnpublish(BuildContext context) async {
    // Capture references before closing the bottom sheet
    final feedProvider = context.read<FeedProvider>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    navigator.pop(); // Close menu

    final confirm = await showDialog<bool>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: const Text('Unpublish Post?'),
        content: const Text(
          'This will remove the post from the public feed. You can republish it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpublish'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await feedProvider.unpublishPost(post.id);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Post unpublished' : 'Failed to unpublish post',
          ),
        ),
      );
    }
  }

  void _handleDelete(BuildContext context) async {
    // Capture references before closing the bottom sheet
    final feedProvider = context.read<FeedProvider>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    navigator.pop(); // Close menu

    final confirm = await showDialog<bool>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await feedProvider.deletePost(post.id);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(success ? 'Post deleted' : 'Failed to delete post'),
        ),
      );
    }
  }

  void _handleReport(BuildContext context) {
    Navigator.pop(context); // Close menu
    // Show report sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReportSheet(
        reportType: 'post',
        referenceId: post.id,
        reportedUserId: post.author.userId ?? '',
        username: post.author.username,
      ),
    );
  }

  // Helper to check if context is mounted since we are in a stateless widget
  // and need to be careful with async gaps.
  // Actually, we can just use the passed context if we are sure it's valid,
  // but standard practice suggests strict checks.
  // For simplicity here, we assume context is valid if we are not navigating away wildly.
  bool mounted(BuildContext context) => context.mounted;
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback? onTap;

  const _MenuOption({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? const Color(0xFFEF4444) : colors.onSurface;

    return InkWell(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: destructive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
