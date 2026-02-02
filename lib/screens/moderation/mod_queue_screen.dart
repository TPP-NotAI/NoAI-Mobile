import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/post_repository.dart';
import '../../utils/time_utils.dart';
import 'appeal_form_screen.dart';

class ModQueueScreen extends StatefulWidget {
  const ModQueueScreen({super.key});

  @override
  State<ModQueueScreen> createState() => _ModQueueScreenState();
}

class _ModQueueScreenState extends State<ModQueueScreen> {
  // Filters (Visual only for now, could be wired up later)
  final String _selectedFilter = 'Priority';
  final String _selectedSort = 'Most Reported';
  final String _selectedType = 'Violation Type';

  List<Post> _queue = [];
  bool _isLoading = true;
  String? _currentUserId;

  final PostRepository _postRepo = PostRepository();

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<AuthProvider>().currentUser?.id;
    _fetchQueue();
  }

  Future<void> _fetchQueue() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _postRepo.getModerationQueue();
      if (mounted) {
        setState(() {
          _queue = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading queue: $e')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mod Queue',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: scheme.onSurface,
            onPressed: _fetchQueue,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards (Mock for now or could count list)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.warning,
                    iconColor: Colors.orange,
                    label: 'BACKLOG',
                    value: _queue.length.toString(),
                    subtitle: 'Pending Review',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.check_circle,
                    iconColor: Colors.blue,
                    label: 'DAILY ACTIONS',
                    value: '45', // Placeholder
                    subtitle: 'Target: 100',
                  ),
                ),
              ],
            ),
          ),

          // Filters (Visual Only)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  label: _selectedFilter,
                  isPrimary: true,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: _selectedSort,
                  isPrimary: false,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: _selectedType,
                  isPrimary: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Queue Items
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _queue.isEmpty
                ? Center(
                    child: Text(
                      '🎉 All caught up!',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _queue.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = _queue[index];
                      return _buildPostItem(context, post);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isPrimary,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? AppColors.primary : scheme.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : scheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: isPrimary ? Colors.white : scheme.onSurface.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(BuildContext context, Post post) {
    final scheme = Theme.of(context).colorScheme;
    final isAI = (post.aiConfidenceScore ?? 0) >= 75;
    final violationColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Violation Header
          Row(
            children: [
              Icon(Icons.auto_awesome, color: violationColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Content Detected',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: violationColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: violationColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'High Confidence',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: violationColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // User Info
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.onSurface.withOpacity(0.1),
                backgroundImage: post.author.avatar.isNotEmpty
                    ? NetworkImage(post.author.avatar)
                    : null,
                child: post.author.avatar.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 20,
                        color: scheme.onSurface.withOpacity(0.5),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.author.username,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          humanReadableTime(post.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    if (post.author.isVerified)
                      Row(
                        children: const [
                          Icon(Icons.verified, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Verified Human',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Content
          Text(
            post.content,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.8),
              height: 1.4,
            ),
          ),

          if (post.hasMedia && post.primaryMediaUrl != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.background,
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(post.primaryMediaUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],

          if (post.aiConfidenceScore != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.psychology, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI ANALYSIS RESULTS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confidence Score: ${(post.aiConfidenceScore!).toStringAsFixed(2)}%.\nSystem flagged this content for review.',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Appeal button — only for current user's own posts
          if (_currentUserId != null &&
              post.author.userId == _currentUserId) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppealFormScreen(post: post),
                    ),
                  );
                },
                icon: const Icon(Icons.gavel, size: 18),
                label: const Text('Appeal This Decision'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
