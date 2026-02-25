import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import '../providers/user_provider.dart';
import '../utils/responsive_extensions.dart';
import '../config/app_spacing.dart';
import '../config/app_typography.dart';

import '../models/post.dart';
import '../providers/feed_provider.dart';
import '../providers/auth_provider.dart';
import '../config/supabase_config.dart';
import '../screens/bookmarks/bookmarks_screen.dart';
import '../screens/create/edit_post_screen.dart';
import '../screens/hashtag_feed_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/ads/ad_insights_page.dart';
import '../utils/time_utils.dart';
import 'video_player_widget.dart';
import 'full_screen_media_viewer.dart';
import 'report_sheet.dart';
import 'shimmer_loading.dart';
import 'mention_rich_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/boost_repository.dart';
import '../repositories/mention_repository.dart';
import '../repositories/wallet_repository.dart';
import '../services/rooken_service.dart';
import '../services/supabase_service.dart';
import '../services/kyc_verification_service.dart';
import 'tip_modal.dart';
import 'boost_post_modal.dart';
import '../screens/boost/boost_analytics_page.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
// ---------------------------------------------------------------------------
// Public cache so boost_post_modal.dart can mark a post as boosted immediately
// after a successful boost, causing the Sponsored badge to appear on the card.
// ---------------------------------------------------------------------------
class PostBoostCache {
  PostBoostCache._();

  static final Set<String> _boostedPostIds = {};
  static final ValueNotifier<int> _version = ValueNotifier<int>(0);
  static bool _loaded = false;
  static Future<void>? _loadFuture;

  static bool isBoosted(String postId) => _boostedPostIds.contains(postId);
  static ValueListenable<int> get changes => _version;

  static void markBoosted(String postId) {
    final inserted = _boostedPostIds.add(postId);
    if (inserted) {
      _version.value++;
    }
    _loaded = true;
  }

  static Future<void> ensureLoaded(String userId) {
    if (_loaded) return Future.value();
    _loadFuture ??= _fetch(userId);
    return _loadFuture!;
  }

  static Future<void> _fetch(String userId) async {
    try {
      final ids = await BoostRepository().getBoostedPostIds(userId);
      final before = _boostedPostIds.length;
      _boostedPostIds.addAll(ids);
      if (_boostedPostIds.length != before) {
        _version.value++;
      }
      _loaded = true;
    } catch (_) {
      // Silently fail — badge just won't show
    }
  }
}

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

    void handleHashtagTap(String hashtag) {
      if (onHashtagTap != null) {
        onHashtagTap!(hashtag);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HashtagFeedScreen(hashtag: hashtag)),
      );
    }

    void openPostDetails() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.standard.responsive(context),
        vertical: AppSpacing.mediumSmall.responsive(context),
      ),
      child: GestureDetector(
        onTap: openPostDetails,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppSpacing.responsiveRadius(
              context,
              AppSpacing.radiusExtraLarge,
            ),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16.responsive(context),
                offset: Offset(0, 8.responsive(context)),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.largePlus.responsive(context),
                    vertical: AppSpacing.mediumSmall.responsive(context),
                  ),
                  color: colors.errorContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: AppTypography.responsiveIconSize(context, 16),
                        color: colors.onErrorContainer,
                      ),
                      SizedBox(
                        width: AppSpacing.mediumSmall.responsive(context),
                      ),
                      Expanded(
                        child: Text('This post is under review.'.tr(context),
                          style: TextStyle(
                            fontSize: AppTypography.responsiveFontSize(
                              context,
                              AppTypography.badgeText,
                            ),
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (post.isSensitive)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(
                    horizontal: AppSpacing.largePlus.responsive(context),
                    vertical: AppSpacing.mediumSmall.responsive(context),
                  ),
                  padding: AppSpacing.responsiveAll(
                    context,
                    AppSpacing.standard,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.1),
                    borderRadius: AppSpacing.responsiveRadius(
                      context,
                      AppSpacing.radiusLarge,
                    ),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colors.error,
                        size: AppTypography.responsiveIconSize(context, 24),
                      ),
                      SizedBox(width: AppSpacing.standard.responsive(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sensitive Content'.tr(context),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.error,
                                fontSize: AppTypography.responsiveFontSize(
                                  context,
                                  AppTypography.base,
                                ),
                              ),
                            ),
                            if (post.sensitiveReason != null)
                              Text(
                                post.sensitiveReason!,
                                style: TextStyle(
                                  fontSize: AppTypography.responsiveFontSize(
                                    context,
                                    AppTypography.badgeText,
                                  ),
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
                  padding: AppSpacing.responsiveLTRB(context, 16, 8, 16, 0),
                  child: MentionRichText(
                    text: post.title!,
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.cardHeading,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                    onMentionTap: (username) =>
                        navigateToMentionedUser(context, username),
                    onHashtagTap: handleHashtagTap,
                  ),
                ),

              _Content(post: post, onHashtagTap: handleHashtagTap),

              if (post.tags != null && post.tags!.isNotEmpty)
                Padding(
                  padding: AppSpacing.responsiveLTRB(context, 16, 8, 16, 8),
                  child: Wrap(
                    spacing: AppSpacing.mediumSmall.responsive(context),
                    runSpacing: AppSpacing.extraSmall.responsive(context),
                    children: post.tags!.map((tag) {
                      return GestureDetector(
                        onTap: () => handleHashtagTap(tag.name),
                        child: Text('#${tag.name}'.tr(context),
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTypography.responsiveFontSize(
                              context,
                              AppTypography.small,
                            ),
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
  bool _isResolvingMentionUsernames = false;
  final List<String> _resolvedMentionUsernames = [];
  final MentionRepository _mentionRepository = MentionRepository();

  // Bounded caches (max 500 entries) for geocoded locations and mention usernames.
  static final Map<String, String> _locationCache = {};
  static final Map<String, String> _mentionUsernameCache = {};
  static const int _maxCacheSize = 500;

  static void _addToCache(Map<String, String> cache, String key, String value) {
    if (cache.length >= _maxCacheSize) {
      cache.remove(cache.keys.first);
    }
    cache[key] = value;
  }

  bool _isBoosted = false;

  bool _isAdvertPost(Post post) {
    final notes = (post.authenticityNotes ?? '').toLowerCase();
    if (notes.contains('advertisement:')) return true;
    final ad = post.aiMetadata?['advertisement'];
    if (ad is Map) {
      return ad['requires_payment'] == true ||
          (ad['confidence'] is num && (ad['confidence'] as num) >= 40);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _resolveMentionUsernames();
    _ensureBoostCacheLoaded();
    PostBoostCache.changes.addListener(_handleBoostCacheChanged);
  }

  @override
  void dispose() {
    PostBoostCache.changes.removeListener(_handleBoostCacheChanged);
    super.dispose();
  }

  void _handleBoostCacheChanged() {
    if (!mounted) return;
    final boosted = PostBoostCache.isBoosted(widget.post.id);
    if (boosted != _isBoosted) {
      setState(() {
        _isBoosted = boosted;
      });
    }
  }

  void _ensureBoostCacheLoaded() {
    // Sync check first — cache may already be warm
    if (PostBoostCache.isBoosted(widget.post.id)) {
      _isBoosted = true;
      return;
    }
    final userId = SupabaseService().client.auth.currentUser?.id;
    if (userId == null) return;
    PostBoostCache.ensureLoaded(userId).then((_) {
      if (mounted) {
        setState(() {
          _isBoosted = PostBoostCache.isBoosted(widget.post.id);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Header oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isBoosted = PostBoostCache.isBoosted(widget.post.id);
    }
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.mentionedUserIds != widget.post.mentionedUserIds ||
        oldWidget.post.content != widget.post.content) {
      _resolvedMentionUsernames.clear();
      _resolveMentionUsernames();
    }
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
        _addToCache(_locationCache, coordinates, humanReadable);

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

  Future<void> _resolveMentionUsernames() async {
    final ids = widget.post.mentionedUserIds ?? const <String>[];
    if (ids.isEmpty) return;

    final unresolvedIds = ids
        .where((id) => !_mentionUsernameCache.containsKey(id))
        .toList();

    if (unresolvedIds.isNotEmpty) {
      setState(() => _isResolvingMentionUsernames = true);
      final resolved = await _mentionRepository.resolveUserIdsToUsernames(
        unresolvedIds,
      );
      for (final entry in resolved.entries) {
        _addToCache(_mentionUsernameCache, entry.key, entry.value);
      }
    }

    if (!mounted) return;
    setState(() {
      _resolvedMentionUsernames
        ..clear()
        ..addAll(
          ids
              .map((id) => _mentionUsernameCache[id])
              .whereType<String>()
              .map((u) => u.toLowerCase())
              .toSet(),
        );
      _isResolvingMentionUsernames = false;
    });
  }

  List<String> _extractInlineMentions(String text) {
    final matches = RegExp(r'@(\w+)').allMatches(text);
    return matches.map((m) => m.group(1)).whereType<String>().toSet().toList();
  }

  String? _buildMentionSummary(Post post) {
    final inlineMentions = _extractInlineMentions(post.content);
    final displayMentions = [
      ..._resolvedMentionUsernames,
      ...inlineMentions,
    ].toSet().toList();

    final totalMentionedCount =
        (post.mentionedUserIds?.toSet().length ?? 0) > displayMentions.length
        ? (post.mentionedUserIds?.toSet().length ?? 0)
        : displayMentions.length;

    if (totalMentionedCount <= 0) return null;

    if (displayMentions.isEmpty) {
      return totalMentionedCount == 1
          ? 'with 1 person'
          : 'with $totalMentionedCount people';
    }

    if (displayMentions.length == 1 || totalMentionedCount == 1) {
      return 'with @${displayMentions.first}';
    }

    if (displayMentions.length >= 2) {
      final first = '@${displayMentions[0]}';
      final second = '@${displayMentions[1]}';
      final shownCount = 2;
      final others = totalMentionedCount - shownCount;
      if (others > 0) {
        return 'with $first, $second and $others other${others == 1 ? '' : 's'}';
      }
      return 'with $first and $second';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final post = widget.post;
    final mentionSummary = _buildMentionSummary(post);

    return Padding(
      padding: AppSpacing.responsiveLTRB(context, 16, 16, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onProfileTap,
            child: CircleAvatar(
              radius: 22.responsive(context, min: 18, max: 26),
              backgroundImage: post.author.avatar.isNotEmpty
                  ? NetworkImage(post.author.avatar)
                  : null,
              backgroundColor: colors.surfaceContainerHighest,
              child: post.author.avatar.isEmpty
                  ? Icon(
                      Icons.person,
                      color: colors.onSurfaceVariant,
                      size: AppTypography.responsiveIconSize(context, 22),
                    )
                  : null,
            ),
          ),
          SizedBox(width: AppSpacing.standard.responsive(context)),
          Expanded(
            child: GestureDetector(
              onTap: widget.onProfileTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.author.displayName.isNotEmpty
                              ? post.author.displayName
                              : post.author.username,
                          style: TextStyle(
                            fontSize: AppTypography.responsiveFontSize(
                              context,
                              AppTypography.small,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.author.isVerified) ...[
                        SizedBox(
                          width: AppSpacing.extraSmall.responsive(context),
                        ),
                        Icon(
                          Icons.verified,
                          size: AppTypography.responsiveIconSize(context, 14),
                          color: colors.primary,
                        ),
                      ],
                      if (post.author.displayName.isNotEmpty &&
                          post.author.displayName.toLowerCase() !=
                              post.author.username.toLowerCase()) ...[
                        SizedBox(width: AppSpacing.small.responsive(context)),
                        Flexible(
                          child: Text('@${post.author.username}'.tr(context),
                            style: TextStyle(
                              fontSize: AppTypography.responsiveFontSize(
                                context,
                                AppTypography.badgeText,
                              ),
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (mentionSummary != null) ...[
                    SizedBox(height: AppSpacing.extraSmall.responsive(context)),
                    MentionRichText(
                      text: _isResolvingMentionUsernames
                          ? '$mentionSummary...'
                          : mentionSummary,
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          AppTypography.badgeText,
                        ),
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      mentionStyle: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          AppTypography.badgeText,
                        ),
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      onMentionTap: (username) {
                        navigateToMentionedUser(context, username);
                      },
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  SizedBox(height: AppSpacing.extraSmall.responsive(context)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            humanReadableTime(post.timestamp),
                            style: TextStyle(
                              fontSize: AppTypography.responsiveFontSize(
                                context,
                                11,
                              ),
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.small.responsive(context)),
                          _MlScoreBadge(
                            score: post.aiConfidenceScore,
                            isModerated: post.status == 'under_review',
                          ),
                          if (_isAdvertPost(post)) ...[
                            SizedBox(
                              width: AppSpacing.small.responsive(context),
                            ),
                            const _AdBadge(),
                          ],
                          if (_isBoosted) ...[
                            SizedBox(
                              width: AppSpacing.small.responsive(context),
                            ),
                            const _SponsoredBadge(),
                          ],
                        ],
                      ),
                      if (post.location != null &&
                          post.location!.isNotEmpty) ...[
                        SizedBox(height: 2.responsive(context)),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: AppTypography.responsiveIconSize(
                                context,
                                12,
                              ),
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            SizedBox(width: 2.responsive(context)),
                            Flexible(
                              child: _isLoadingLocation
                                  ? SizedBox(
                                      width: 12.responsive(context),
                                      height: 12.responsive(context),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: colors.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                      ),
                                    )
                                  : Text(
                                      _displayLocation ?? post.location!,
                                      style: TextStyle(
                                        fontSize:
                                            AppTypography.responsiveFontSize(
                                              context,
                                              11,
                                            ),
                                        color: colors.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ],
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
            icon: Icon(
              Icons.more_horiz,
              color: colors.onSurfaceVariant,
              size: AppTypography.responsiveIconSize(context, 24),
            ),
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
      builder: (_) => _PostMenu(post: widget.post, isBoosted: _isBoosted),
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
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text('${post.reposter!.displayName.isNotEmpty ? post.reposter!.displayName : post.reposter!.username} reposted'.tr(context),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── SPONSORED BADGE ───────────────── */

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rocket_launch, size: 9, color: Color(0xFFF97316)),
          SizedBox(width: 3),
          Text('Sponsored'.tr(context),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF97316),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdBadge extends StatelessWidget {
  const _AdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C00).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFF8C00).withValues(alpha: 0.5),
        ),
      ),
      child: Text('AD'.tr(context),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFF8C00),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/* ───────────────── ML SCORE BADGE ───────────────── */

class _MlScoreBadge extends StatelessWidget {
  final double? score;
  final bool isModerated;

  const _MlScoreBadge({required this.score, this.isModerated = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final bool isPending = score == null;

    final Color badgeColor;
    final Color bgColor;
    final String label;

    // Theme-aware colors
    const greenAccent = Color(0xFF10B981);
    const amberAccent = Color(0xFFF59E0B);
    const redAccent = Color(0xFFEF4444);
    const grayAccent = Color(0xFF9CA3AF);

    // Convert AI confidence score to Human score (invert it)
    // API returns AI probability, we display Human probability
    final double? humanScore = score != null ? 100 - score! : null;

    // API Thresholds (AI confidence):
    // - 95%+ AI = BLOCK (auto-block)
    // - 75-94% AI = FLAG (flag for review)
    // - 60-74% AI = LABEL (add transparency label)
    // - <60% AI = ALLOW (no action)
    //
    // Inverted for Human Score display:
    // - <5% human = BLOCKED
    // - 5-25% human = FLAG/REVIEW
    // - 26-40% human = LABEL
    // - >40% human = PASS

    if (isModerated) {
      badgeColor = amberAccent;
      bgColor = isDark
          ? const Color(0xFF451A03)
          : amberAccent.withValues(alpha: 0.15);
      label = 'UNDER REVIEW';
    } else if (isPending) {
      badgeColor = isDark ? grayAccent : colors.onSurfaceVariant;
      bgColor = isDark
          ? const Color(0xFF1F2937)
          : colors.surfaceContainerHighest;
      label = 'PENDING';
    } else if (humanScore! > 40) {
      // >40% human (AI <60%) = PASS -> VERIFIED
      badgeColor = greenAccent;
      bgColor = isDark
          ? const Color(0xFF052E1C)
          : greenAccent.withValues(alpha: 0.15);
      label = 'VERIFIED';
    } else if (humanScore > 25) {
      // 26-40% human (AI 60-74%) = LABEL -> REVIEW
      badgeColor = amberAccent;
      bgColor = isDark
          ? const Color(0xFF451A03)
          : amberAccent.withValues(alpha: 0.15);
      label = 'REVIEW';
    } else if (humanScore > 5) {
      // 5-25% human (AI 75-94%) = FLAG -> FLAGGED
      badgeColor = redAccent;
      bgColor = isDark
          ? const Color(0xFF2D0F0F)
          : redAccent.withValues(alpha: 0.15);
      label = 'FLAGGED';
    } else {
      // <5% human (AI 95%+) = BLOCKED -> AI DETECTED
      badgeColor = redAccent;
      bgColor = isDark
          ? const Color(0xFF2D0F0F)
          : redAccent.withValues(alpha: 0.15);
      label = 'AI DETECTED';
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
          SizedBox(width: 8),
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
  final void Function(String hashtag)? onHashtagTap;

  const _Content({required this.post, this.onHashtagTap});

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
              _expanded || !isOverflowing
                  ? MentionRichText(
                      text: post.content,
                      style: textStyle,
                      onMentionTap: (username) =>
                          navigateToMentionedUser(context, username),
                      onHashtagTap: widget.onHashtagTap,
                    )
                  : MentionRichText(
                      text: post.content,
                      style: textStyle,
                      maxLines: _maxLines,
                      overflow: TextOverflow.clip,
                      onMentionTap: (username) =>
                          navigateToMentionedUser(context, username),
                      onHashtagTap: widget.onHashtagTap,
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
          SizedBox(width: 2),
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
          SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _MediaTile(item: items[1], post: post, index: 1),
                ),
                SizedBox(height: 2),
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
                SizedBox(width: 2),
                Expanded(
                  child: _MediaTile(item: items[1], post: post, index: 1),
                ),
              ],
            ),
          ),
          SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaTile(item: items[2], post: post, index: 2),
                ),
                SizedBox(width: 2),
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
                SizedBox(width: 2),
                Expanded(
                  child: _MediaTile(item: items[1], post: post, index: 1),
                ),
              ],
            ),
          ),
          SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaTile(item: items[2], post: post, index: 2),
                ),
                SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _MediaTile(item: items[3], post: post, index: 3),
                      Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Center(
                          child: Text('+$extraCount'.tr(context),
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
                  color: colors.surfaceContainerHighest,
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Verified'.tr(context),
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

class _Actions extends StatefulWidget {
  final Post post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onTipTap;

  const _Actions({required this.post, this.onCommentTap, this.onTipTap});

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  Post? _postOverride;

  Post _resolvedPost(FeedProvider feedProvider) {
    final index = feedProvider.posts.indexWhere((p) => p.id == widget.post.id);
    final providerPost = index != -1 ? feedProvider.posts[index] : null;
    final localOverride = _postOverride;

    if (localOverride != null) {
      final base = providerPost ?? widget.post;
      return base.copyWith(
        isLiked: localOverride.isLiked,
        likes: localOverride.likes,
      );
    }

    return providerPost ?? widget.post;
  }

  @override
  void didUpdateWidget(covariant _Actions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _postOverride = null;
    }
  }

  void _applyLocalPostLikeToggle(Post post) {
    final nextIsLiked = !post.isLiked;
    final nextLikes = nextIsLiked
        ? post.likes + 1
        : (post.likes - 1).clamp(0, 1 << 30);
    setState(() {
      _postOverride = post.copyWith(isLiked: nextIsLiked, likes: nextLikes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<FeedProvider>();
    final post = _resolvedPost(feedProvider);
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isBookmarked = feedProvider.isBookmarked(post.id);
    final isReposted = feedProvider.isReposted(post.id);
    final repostCount = feedProvider.getRepostCount(post.id);
    final isSelf = currentUserId == post.authorId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _ActionButton(
            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
            label: _format(post.likes),
            isLiked: post.isLiked,
            onTap: () => _handleLike(context, feedProvider, post),
          ),
          SizedBox(width: 4),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: _format(post.comments),
            onTap: widget.onCommentTap,
          ),
          SizedBox(width: 4),
          _ActionButton(
            icon: Icons.repeat,
            label: repostCount > 0 ? _format(repostCount) : null,
            isReposted: isReposted,
            onTap: () => _handleRepost(context, feedProvider),
          ),
          if (!isSelf) ...[
            SizedBox(width: 4),
            _ActionButton(
              icon: Icons.toll,
              label: post.tips > 0 ? '${_format(post.tips.toInt())} ROO' : null,
              onTap: widget.onTipTap ?? () => _handleTip(context),
            ),
          ],
          Spacer(),
          _ActionButton(
            icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            isBookmarked: isBookmarked,
            onTap: () => _handleBookmark(context, feedProvider, isBookmarked),
          ),
          SizedBox(width: 4),
          _ActionButton(
            icon: Icons.share_outlined,
            onTap: () => _handleShare(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLike(
    BuildContext context,
    FeedProvider feedProvider,
    Post currentPost,
  ) async {
    // Always apply local toggle first for immediate UI feedback
    if (mounted) {
      _applyLocalPostLikeToggle(currentPost);
    }
    try {
      await feedProvider.toggleLike(currentPost.id);
    } on KycNotVerifiedException catch (e) {
      // Revert the toggle if there's an error
      if (mounted) {
        _applyLocalPostLikeToggle(_resolvedPost(feedProvider));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Verify',
                textColor: Colors.white,
                onPressed: () {
                  if (context.mounted) {
                    Navigator.pushNamed(context, '/verify');
                  }
                },
              ),
            ),
          );
      }
    } on NotActivatedException catch (e) {
      // Revert the toggle if there's an error
      if (mounted) {
        _applyLocalPostLikeToggle(_resolvedPost(feedProvider));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Buy ROO',
                textColor: Colors.white,
                onPressed: () {
                  if (context.mounted) {
                    Navigator.pushNamed(context, '/wallet');
                  }
                },
              ),
            ),
          );
      }
    }
  }

  void _handleTip(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    if (user.isVerificationPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your verification is pending. You can tip once approved.'.tr(context),
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!user.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete identity verification to send tips.'.tr(context),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Verify',
            textColor: Colors.white,
            onPressed: () {
              if (context.mounted) {
                Navigator.pushNamed(context, '/verify');
              }
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TipModal(post: widget.post),
    );
  }

  Future<void> _handleRepost(
    BuildContext context,
    FeedProvider feedProvider,
  ) async {
    try {
      final wasReposted = feedProvider.isReposted(widget.post.id);
      await feedProvider.toggleRepost(widget.post.id);

      if (context.mounted) {
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
    } on KycNotVerifiedException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Verify',
                textColor: Colors.white,
                onPressed: () {
                  if (context.mounted) {
                    Navigator.pushNamed(context, '/verify');
                  }
                },
              ),
            ),
          );
      }
    } on NotActivatedException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Buy ROO',
                textColor: Colors.white,
                onPressed: () {
                  if (context.mounted) {
                    Navigator.pushNamed(context, '/wallet');
                  }
                },
              ),
            ),
          );
      }
    }
  }

  void _handleBookmark(
    BuildContext context,
    FeedProvider feedProvider,
    bool wasBookmarked,
  ) {
    feedProvider.toggleBookmark(widget.post.id);

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
      final currentUserId = context.read<AuthProvider>().currentUser?.id;

      // Create share text
      final shareText = widget.post.title != null && widget.post.title!.isNotEmpty
          ? '${widget.post.title}\n\n${widget.post.content}\n\nShared from ROOVERSE'
          : '${widget.post.content}\n\nShared from ROOVERSE';

      // Share using native share dialog
      await Share.share(
        shareText,
        subject: widget.post.title ?? 'Check out this post on ROOVERSE',
      );

      // Award 5 ROO to the user who shared the post
      if (currentUserId != null && currentUserId.isNotEmpty) {
        try {
          final walletRepo = WalletRepository();
          await walletRepo.earnRoo(
            userId: currentUserId,
            activityType: RookenActivityType.postShare,
            referencePostId: widget.post.id,
          );
        } catch (e) {
          debugPrint('Error awarding share ROOK: $e');
        }
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Post shared! You earned 5 ROOK.'.tr(context)),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              if (label != null) ...[
                SizedBox(width: 6),
                Text(label!, style: TextStyle(fontSize: 13, color: textColor)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────── POST MENU ───────────────── */

class _PostMenu extends StatelessWidget {
  final Post post;
  final bool isBoosted;

  const _PostMenu({required this.post, this.isBoosted = false});

  bool get _isAdvertPost {
    final notes = (post.authenticityNotes ?? '').toLowerCase();
    if (notes.contains('advertisement:')) return true;
    final ad = post.aiMetadata?['advertisement'];
    if (ad is Map) {
      return ad['requires_payment'] == true ||
          (ad['confidence'] is num && (ad['confidence'] as num) >= 40);
    }
    return false;
  }

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
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).padding.bottom + 16,
        ),
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
            SizedBox(height: 24),
            if (isAuthor) ...[
              _MenuOption(
                icon: Icons.rocket_launch,
                label: 'Boost Post',
                onTap: () => _handleBoost(context),
              ),
              if (isBoosted)
                _MenuOption(
                  icon: Icons.bar_chart,
                  label: 'View Boost Analytics',
                  onTap: () => _handleBoostAnalytics(context),
                ),
              if (_isAdvertPost)
                _MenuOption(
                  icon: Icons.insights_outlined,
                  label: 'Ad Insights',
                  onTap: () => _handleAdInsights(context),
                ),
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
                    SnackBar(content: Text('Post saved to bookmarks'.tr(context))),
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
                    SnackBar(content: Text('Link copied to clipboard'.tr(context))),
                  );
                },
              ),
              _MenuOption(
                icon: Icons.report_outlined,
                label: 'Report',
                onTap: () => _handleReport(context),
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
                          content: Text('@${post.author.username} blocked.'.tr(context)),
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

  void _handleBoost(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BoostPostModal(post: post),
    );
  }

  void _handleBoostAnalytics(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BoostAnalyticsPage(post: post)),
    );
  }

  void _handleAdInsights(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdInsightsPage(post: post)),
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
        title: Text('Unpublish Post?'.tr(context)),
        content: Text('This will remove the post from the public feed. You can republish it later.'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unpublish'.tr(context)),
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
        title: Text('Delete Post?'.tr(context)),
        content: Text('Are you sure you want to delete this post? This action cannot be undone.'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: destructive
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
