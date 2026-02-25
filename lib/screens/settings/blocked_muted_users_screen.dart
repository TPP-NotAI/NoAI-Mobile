import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/user_card.dart';
import '../../models/user.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class BlockedMutedUsersScreen extends StatefulWidget {
  // initialIndex kept for API compatibility
  final int initialIndex;

  const BlockedMutedUsersScreen({super.key, this.initialIndex = 0});

  @override
  State<BlockedMutedUsersScreen> createState() =>
      _BlockedMutedUsersScreenState();
}

class _BlockedMutedUsersScreenState extends State<BlockedMutedUsersScreen> {
  List<User> _blockedUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final blockedIds = userProvider.blockedUserIds;
      final results = await userProvider.fetchUsersByIds(blockedIds);

      if (mounted) {
        setState(() {
          _blockedUsers = results;
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
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text('Blocked Users'.tr(context),
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading blocked users...')
          : _error != null
          ? ErrorDisplayWidget(message: _error!, onRetry: _loadData)
          : _buildUserList(_blockedUsers),
    );
  }

  Widget _buildUserList(List<User> users) {
    final scheme = Theme.of(context).colorScheme;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: scheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text('No blocked users'.tr(context),
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.6),
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
          onTap: () {},
          trailing: TextButton(
            onPressed: () => _unblock(user),
            child: Text('Unblock'.tr(context), style: TextStyle(color: Colors.red)),
          ),
        );
      },
    );
  }

  Future<void> _unblock(User user) async {
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.toggleBlock(user.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.username} unblocked.'.tr(context))),
      );
      _loadData();
    }
  }
}
