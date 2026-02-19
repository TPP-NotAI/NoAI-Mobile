import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/user_card.dart';
import 'user_detail_screen.dart';
import 'profile/profile_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<UserProvider>().fetchUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<UserProvider>().fetchUsers(),
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.isLoading && userProvider.users.isEmpty) {
            return const LoadingWidget(message: 'Loading users...');
          }

          if (userProvider.error != null && userProvider.users.isEmpty) {
            return ErrorDisplayWidget(
              message: userProvider.error!,
              onRetry: () => userProvider.fetchUsers(),
            );
          }

          // Use filteredUsers to hide blocked users
          final displayUsers = userProvider.filteredUsers;

          if (displayUsers.isEmpty) {
            return const Center(child: Text('No users available'));
          }

          return RefreshIndicator(
            onRefresh: () => userProvider.fetchUsers(),
            child: ListView.builder(
              itemCount: displayUsers.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final user = displayUsers[index];
                return UserCard(
                  user: user,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProfileScreen(userId: user.id, showAppBar: true),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
