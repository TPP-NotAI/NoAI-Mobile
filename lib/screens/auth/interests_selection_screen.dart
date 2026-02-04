import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../repositories/user_interests_repository.dart';
import '../../providers/user_provider.dart';
import 'package:provider/provider.dart';

class InterestsSelectionScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const InterestsSelectionScreen({super.key, required this.onComplete});

  @override
  State<InterestsSelectionScreen> createState() =>
      _InterestsSelectionScreenState();
}

class _InterestsSelectionScreenState extends State<InterestsSelectionScreen> {
  final Set<String> _selectedInterests = {};
  bool _isLoading = false;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _showProfileFields = false;

  // Predefined interest categories with topics
  final Map<String, List<String>> _interestCategories = {
    'Technology': [
      'programming',
      'ai',
      'web-development',
      'mobile-apps',
      'cybersecurity',
      'blockchain',
      'gadgets',
      'software',
    ],
    'Science': [
      'physics',
      'biology',
      'chemistry',
      'astronomy',
      'medicine',
      'environment',
      'research',
    ],
    'Arts & Culture': [
      'music',
      'art',
      'literature',
      'photography',
      'film',
      'theater',
      'design',
      'fashion',
    ],
    'Sports & Fitness': [
      'football',
      'basketball',
      'fitness',
      'running',
      'yoga',
      'cycling',
      'tennis',
      'soccer',
    ],
    'Food & Cooking': [
      'recipes',
      'baking',
      'vegan',
      'restaurants',
      'coffee',
      'wine',
      'cooking-tips',
    ],
    'Travel': [
      'adventure',
      'photography',
      'backpacking',
      'luxury-travel',
      'culture',
      'food-travel',
    ],
    'Business & Finance': [
      'entrepreneurship',
      'investing',
      'cryptocurrency',
      'startups',
      'marketing',
      'economics',
    ],
    'Lifestyle': [
      'self-improvement',
      'productivity',
      'minimalism',
      'wellness',
      'mindfulness',
      'home-decor',
    ],
    'Gaming': [
      'pc-gaming',
      'console-gaming',
      'mobile-games',
      'esports',
      'game-development',
      'retro-gaming',
    ],
    'Education': [
      'learning',
      'online-courses',
      'tutoring',
      'languages',
      'academic',
      'skills',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadSavedInterests();
    _checkProfileFields();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _checkProfileFields() {
    final user = context.read<UserProvider>().currentUser;
    if (user != null) {
      setState(() {
        _displayNameController.text = user.displayName;
        _bioController.text = user.bio ?? '';
        _showProfileFields =
            user.displayName.isEmpty || (user.bio == null || user.bio!.isEmpty);
      });
    }
  }

  Future<void> _loadSavedInterests() async {
    final saved = await UserInterestsRepository().getUserInterests();
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _selectedInterests.addAll(saved);
      });
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _saveAndContinue() async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;

    if (_showProfileFields && _displayNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }

    if (_showProfileFields && _bioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a bio')));
      return;
    }

    if (_selectedInterests.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least 3 interests to personalize your feed',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save profile updates if needed
      if (_showProfileFields && user != null) {
        final updates = <String, dynamic>{
          'display_name': _displayNameController.text.trim(),
          'bio': _bioController.text.trim(),
        };
        await userProvider.updateProfile(user.id, updates);
      }

      // Save interests
      if (_selectedInterests.isNotEmpty) {
        await UserInterestsRepository().saveUserInterests(
          _selectedInterests.toList(),
        );
      }

      widget.onComplete();
    } catch (e) {
      debugPrint('Error saving profile/interests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            // Scrollable Content (Header + Interests)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      Color(0xFF3B82F6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fingerprint,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'NOAI',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onBackground,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _showProfileFields
                                ? 'Tell us about yourself'
                                : 'What interests you?',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: scheme.onBackground,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _showProfileFields
                                ? 'Set up your identity to start connecting with the community.'
                                : 'Select at least 3 topics to personalize your experience.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: scheme.onBackground.withOpacity(0.6),
                              height: 1.4,
                            ),
                          ),
                          if (_showProfileFields) ...[
                            const SizedBox(height: 32),
                            _buildProfileField(
                              context,
                              label: 'Display Name',
                              controller: _displayNameController,
                              hint: 'What name should we show?',
                              icon: Icons.face_outlined,
                            ),
                            const SizedBox(height: 20),
                            _buildProfileField(
                              context,
                              label: 'Bio',
                              controller: _bioController,
                              hint: 'Professional AI Enthusiast...',
                              icon: Icons.history_edu_outlined,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: scheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'PICK YOUR INTERESTS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: scheme.onBackground.withOpacity(
                                        0.4,
                                      ),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: scheme.outline.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (_selectedInterests.length < 3)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: scheme.error.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: scheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Select ${3 - _selectedInterests.length} more interests to continue',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedInterests.length} selected interests',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Interests List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _interestCategories.entries.map((category) {
                          return _InterestCategory(
                            categoryName: category.key,
                            interests: category.value,
                            selectedInterests: _selectedInterests,
                            onToggle: _toggleInterest,
                          );
                        }).toList(),
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveAndContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    scheme.surfaceContainerHighest,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Continue',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, size: 20),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!_showProfileFields)
                            TextButton(
                              onPressed: _isLoading ? null : widget.onComplete,
                              child: Text(
                                'Skip for now',
                                style: TextStyle(
                                  color: scheme.onBackground.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
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

  Widget _buildProfileField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onBackground.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: scheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _InterestCategory extends StatelessWidget {
  final String categoryName;
  final List<String> interests;
  final Set<String> selectedInterests;
  final Function(String) onToggle;

  const _InterestCategory({
    required this.categoryName,
    required this.interests,
    required this.selectedInterests,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: scheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interests.map((interest) {
              final isSelected = selectedInterests.contains(interest);
              return _InterestChip(
                label: interest
                    .replaceAll('-', ' ')
                    .split(' ')
                    .map((word) {
                      return word.isEmpty
                          ? ''
                          : word[0].toUpperCase() + word.substring(1);
                    })
                    .join(' '),
                isSelected: isSelected,
                onTap: () => onToggle(interest),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _InterestChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : scheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: AppColors.primary)
            else
              Icon(
                Icons.add_circle_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
