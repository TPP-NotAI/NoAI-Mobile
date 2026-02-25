import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:rooverse/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/follow_repository.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class UserSearchSheet extends StatefulWidget {
  const UserSearchSheet({super.key});

  @override
  State<UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<UserSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FollowRepository _followRepository = FollowRepository(
    Supabase.instance.client,
  );

  List<User> _following = [];
  List<User> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    final currentUserId =
        context.read<AuthProvider>().currentUser?.id;
    if (currentUserId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final users = await _followRepository.getFollowing(currentUserId);
      if (mounted) {
        setState(() {
          _following = users;
          _filtered = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('UserSearchSheet: Error loading following - $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase().replaceFirst('@', '');
    setState(() {
      if (q.isEmpty) {
        _filtered = _following;
      } else {
        _filtered = _following.where((u) {
          return u.username.toLowerCase().contains(q) ||
              u.displayName.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('New Message'.tr(context),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search people you follow...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_following.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text('Follow people to start a chat'.tr(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Text('No matching users'.tr(context),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final user = _filtered[index];
                  final name = user.displayName.isNotEmpty
                      ? user.displayName
                      : user.username;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.primaryContainer,
                      backgroundImage: user.avatar != null
                          ? NetworkImage(user.avatar!)
                          : null,
                      child: user.avatar == null
                          ? Icon(
                              Icons.person,
                              color: colors.onPrimaryContainer,
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('@${user.username}'.tr(context)),
                    onTap: () => Navigator.pop(context, user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
