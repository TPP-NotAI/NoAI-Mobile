import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/user_card.dart';
import '../../models/user.dart';
import '../../config/app_colors.dart';

class BlockedMutedUsersScreen extends StatefulWidget {
  final int initialIndex;

  const BlockedMutedUsersScreen({super.key, this.initialIndex = 0});

  @override
  State<BlockedMutedUsersScreen> createState() =>
      _BlockedMutedUsersScreenState();
}

class _BlockedMutedUsersScreenState extends State<BlockedMutedUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _blockedUsers = [];
  List<User> _mutedUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProvider = context.read<UserProvider>();

      // Load both blocked and muted users
      final blockedIds = userProvider.blockedUserIds;
      final mutedIds = userProvider.mutedUserIds;

      final results = await Future.wait([
        userProvider.fetchUsersByIds(blockedIds),
        userProvider.fetchUsersByIds(mutedIds),
      ]);

      if (mounted) {
        setState(() {
          _blockedUsers = results[0];
          _mutedUsers = results[1];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        title: Text(
          'Safety Controls',
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: scheme.onSurface.withOpacity(0.5),
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Blocked'),
            Tab(text: 'Muted'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading safety settings...')
          : _error != null
          ? ErrorDisplayWidget(message: _error!, onRetry: _loadData)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_blockedUsers, isBlock: true),
                _buildUserList(_mutedUsers, isBlock: false),
              ],
            ),
    );
  }

  Widget _buildUserList(List<User> users, {required bool isBlock}) {
    final scheme = Theme.of(context).colorScheme;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBlock ? Icons.block : Icons.volume_off,
              size: 64,
              color: scheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              isBlock ? 'No blocked users' : 'No muted users',
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final user = users[index];
        return UserCard(
          user: user,
          onTap: () {
            // Navigate to profile if needed
          },
          trailing: TextButton(
            onPressed: () => _toggleStatus(user, isBlock),
            child: Text(
              isBlock ? 'Unblock' : 'Unmute',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleStatus(User user, bool isBlock) async {
    final userProvider = context.read<UserProvider>();
    bool success;

    if (isBlock) {
      success = await userProvider.toggleBlock(user.id);
    } else {
      success = await userProvider.toggleMute(user.id);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${user.username} ${isBlock ? 'unblocked' : 'unmuted'}.',
          ),
        ),
      );
      _loadData(); // Refresh lists
    }
  }
}
