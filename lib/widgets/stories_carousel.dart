import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'story_card.dart';
import '../providers/auth_provider.dart';

class StoriesCarousel extends StatelessWidget {
  const StoriesCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Current user's story (always first)
          if (user != null)
            StoryCard(
              username: user.displayName,
              avatar:
                  user.avatar ?? 'https://picsum.photos/100/100?random=default',
              isCurrentUser: true,
              onTap: () {
                // TODO: Navigate to create story
              },
            ),
          // Other users' stories
          StoryCard(
            username: 'Alex Rivers',
            avatar: 'https://picsum.photos/100/100?random=101',
            onTap: () {
              // TODO: Navigate to view story
            },
          ),
          StoryCard(
            username: 'Dr. Raven',
            avatar: 'https://picsum.photos/100/100?random=102',
            onTap: () {
              // TODO: Navigate to view story
            },
          ),
          StoryCard(
            username: 'Travel Miles',
            avatar: 'https://picsum.photos/100/100?random=103',
            onTap: () {
              // TODO: Navigate to view story
            },
          ),
          StoryCard(
            username: 'Sarah Connor',
            avatar: 'https://picsum.photos/100/100?random=105',
            onTap: () {
              // TODO: Navigate to view story
            },
          ),
          StoryCard(
            username: 'Marcus Wright',
            avatar: 'https://picsum.photos/100/100?random=106',
            onTap: () {
              // TODO: Navigate to view story
            },
          ),
        ],
      ),
    );
  }
}
