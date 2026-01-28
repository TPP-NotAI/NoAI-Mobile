import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/post.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import 'chat/conversation_thread_page.dart';
import '../providers/user_provider.dart';
import '../widgets/report_sheet.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/tip_modal.dart';
import '../repositories/post_repository.dart';


class UserDetailScreen extends StatefulWidget {
  final User user;

  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final PostRepository _postRepository = PostRepository();
  List<Post> _userPosts = [];
  bool _loadingPosts = true;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
    // Load follow status for this user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadFollowStatus(widget.user.id);
    });
  }

  Future<void> _loadUserPosts() async {
    try {
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      final posts = await _postRepository.getPostsByUser(
        widget.user.id,
        currentUserId: currentUserId,
      );
      if (mounted) {
        setState(() {
          _userPosts = posts;
          _loadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load user posts: $e');
      if (mounted) {
        setState(() => _loadingPosts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userProvider = context.watch<UserProvider>();
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isFollowing = userProvider.isFollowing(widget.user.id);
    final isSelf = currentUserId == widget.user.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showUserMenu(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primaryContainer,
                    colors.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colors.surface,
                    child: widget.user.avatar != null
                        ? ClipOval(
                            child: Image.network(
                              widget.user.avatar!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 50,
                                  color: colors.primary,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 50,
                            color: colors.primary,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.user.isVerified) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified, size: 20, color: colors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${widget.user.username}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.user.bio!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatColumn(context, '${widget.user.postsCount}', 'Posts'),
                      const SizedBox(width: 32),
                      _buildStatColumn(context, '${widget.user.followersCount}', 'Followers'),
                      const SizedBox(width: 32),
                      _buildStatColumn(context, '${widget.user.followingCount}', 'Following'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  if (!isSelf)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            await userProvider.toggleFollow(widget.user.id);
                          },
                          icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add),
                          label: Text(isFollowing ? 'Unfollow' : 'Follow'),
                          style: FilledButton.styleFrom(
                            backgroundColor: isFollowing
                                ? colors.surfaceContainerHighest
                                : colors.primary,
                            foregroundColor: isFollowing
                                ? colors.onSurface
                                : colors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final chatProvider = context.read<ChatProvider>();
                            final conversation = await chatProvider.startConversation(
                              widget.user.id,
                            );
                            if (conversation != null && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationThreadPage(
                                    conversation: conversation,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Message'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posts by ${widget.user.displayName}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingPosts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_userPosts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.article_outlined, size: 48, color: colors.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No posts yet',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _userPosts.length,
                      itemBuilder: (context, index) {
                        final post = _userPosts[index];
                        return PostCard(
                          post: post,
                          onCommentTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: colors.surface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (_) => CommentsSheet(post: post),
                            );
                          },
                          onTipTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: colors.surface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (_) => TipModal(post: post),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Report User'),
                onTap: () {
                  Navigator.pop(context);
                  _handleReport(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_off_outlined),
                title: const Text('Mute User'),
                onTap: () {
                  Navigator.pop(context);
                  _handleMute(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined, color: Colors.red),
                title: const Text(
                  'Block User',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleBlock(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _handleReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReportSheet(
        reportType: 'user',
        referenceId: widget.user.id,
        reportedUserId: widget.user.id,
        username: widget.user.username,
      ),
    );
  }

  void _handleMute(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.toggleMute(widget.user.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${widget.user.username} has been muted'
              : 'Failed to mute user',
        ),
      ),
    );
  }

  void _handleBlock(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.toggleBlock(widget.user.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${widget.user.username} has been blocked'
              : 'Failed to block user',
        ),
      ),
    );
  }
}
