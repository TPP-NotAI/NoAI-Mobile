import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../config/supabase_config.dart';
import '../../services/supabase_service.dart';
import '../auth/human_verification_screen.dart';
import '../auth/phone_verification_screen.dart';
import '../support/appeal_profile_screen.dart';
import '../../services/profile_reward_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _twitterController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final SupabaseService _supabase = SupabaseService();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  XFile? _selectedImage;
  String? _newAvatarUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user != null) {
        // Get email from Supabase auth if not in user object
        // Email is stored in auth.users, not profiles table
        final email = user.email ?? _supabase.client.auth.currentUser?.email;

        setState(() {
          _displayNameController.text = user.displayName;
          _usernameController.text = user.username;
          _bioController.text = user.bio ?? '';
          _emailController.text = email ?? '';
          _phoneController.text = user.phone ?? '';
        });

        _loadSocialLinks(user.id);
      }
    });
  }

  Future<void> _loadSocialLinks(String userId) async {
    try {
      final response = await _supabase.client
          .from('profile_links')
          .select()
          .eq('user_id', userId);

      if (response is List && mounted) {
        setState(() {
          for (final link in response) {
            final platform = link['platform'] as String?;
            final url = link['url'] as String? ?? '';
            switch (platform) {
              case 'website':
                _websiteController.text = url;
                break;
              case 'twitter':
                _twitterController.text = url;
                break;
              case 'instagram':
                _instagramController.text = url;
                break;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load social links: $e');
    }
  }

  Future<void> _saveSocialLinks(String userId) async {
    final links = <Map<String, String>>[];

    if (_websiteController.text.trim().isNotEmpty) {
      links.add({
        'user_id': userId,
        'platform': 'website',
        'url': _websiteController.text.trim(),
      });
    }
    if (_twitterController.text.trim().isNotEmpty) {
      links.add({
        'user_id': userId,
        'platform': 'twitter',
        'url': _twitterController.text.trim(),
      });
    }
    if (_instagramController.text.trim().isNotEmpty) {
      links.add({
        'user_id': userId,
        'platform': 'instagram',
        'url': _instagramController.text.trim(),
      });
    }

    try {
      // Delete existing links
      await _supabase.client
          .from('profile_links')
          .delete()
          .eq('user_id', userId);

      // Insert new links
      if (links.isNotEmpty) {
        await _supabase.client.from('profile_links').insert(links);
      }
    } catch (e) {
      debugPrint('Failed to save social links: $e');
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _showImagePickerOptions() async {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Change Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt, color: colors.primary),
                ),
                title: const Text('Take a Photo'),
                subtitle: const Text('Use your camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library, color: colors.secondary),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_newAvatarUrl != null || _selectedImage != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete, color: colors.error),
                  ),
                  title: const Text('Remove Photo'),
                  subtitle: const Text('Delete current selection'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _newAvatarUrl = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        requestFullMetadata: false,
      );

      if (image == null) {
        // User cancelled the picker
        return;
      }

      if (!mounted) return;

      // Crop the image to square format
      final croppedFile = await _cropImage(image.path);
      if (croppedFile != null && mounted) {
        setState(() {
          _selectedImage = XFile(croppedFile.path);
          _newAvatarUrl = null; // Clear any previously uploaded URL
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) {
        String message =
            'Failed to access ${source == ImageSource.camera ? 'camera' : 'photos'}';
        if (e.code == 'camera_access_denied' ||
            e.code == 'photo_access_denied') {
          message =
              'Permission denied. Please enable ${source == ImageSource.camera ? 'camera' : 'photos'} access in your device settings.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                // User can manually open settings
              },
            ),
          ),
        );
      }
    } on Exception catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick image: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<CroppedFile?> _cropImage(String imagePath) async {
    final colors = Theme.of(context).colorScheme;
    final isCompactHeight = MediaQuery.of(context).size.height < 700;

    return await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square
      compressQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Picture',
          toolbarColor: colors.surface,
          toolbarWidgetColor: colors.onSurface,
          backgroundColor: colors.surface,
          activeControlsWidgetColor: colors.primary,
          cropFrameColor: colors.primary,
          cropGridColor: colors.outlineVariant,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true, // Force square aspect ratio
          hideBottomControls: isCompactHeight,
          statusBarColor: colors.surface,
        ),
        IOSUiSettings(
          title: 'Crop Profile Picture',
          aspectRatioLockEnabled: true, // Force square aspect ratio
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          rotateButtonsHidden: isCompactHeight,
          rotateClockwiseButtonHidden: true,
        ),
      ],
    );
  }

  Future<String?> _uploadImage(String userId) async {
    if (_selectedImage == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final fileExt = _selectedImage!.path.split('.').last.toLowerCase();
      final fileName =
          'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      // Upload to Supabase Storage (avatars bucket)
      await _supabase.client.storage
          .from(SupabaseConfig.avatarBucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final publicUrl = _supabase.client.storage
          .from(SupabaseConfig.avatarBucket)
          .getPublicUrl(filePath);

      setState(() {
        _newAvatarUrl = publicUrl;
        _isUploadingImage = false;
      });

      return publicUrl;
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isLoading = true);

    // Upload image if a new one was selected
    String? avatarUrl;
    if (_selectedImage != null) {
      avatarUrl = await _uploadImage(user.id);
      if (avatarUrl == null && mounted) {
        setState(() => _isLoading = false);
        return; // Upload failed, don't save profile
      }
    }

    final updates = <String, dynamic>{
      'display_name': _displayNameController.text.trim(),
      'bio': _bioController.text.trim(),
      'phone_number': _phoneController.text.trim(),
    };

    // Add avatar URL if we uploaded a new image
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl;
    }

    final success = await userProvider.updateProfile(user.id, updates);

    if (success) {
      // Save social links alongside profile
      await _saveSocialLinks(user.id);

      // Refresh user data
      await userProvider.fetchUser(user.id);

      if (mounted) {
        // Check and reward profile completion
        try {
          final rewardService = ProfileRewardService();
          final newlyRewarded = await rewardService
              .checkAndRewardProfileCompletion(user.id);

          if (newlyRewarded && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile complete! Earned 20 ROO 🎉'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error rewarding profile completion: $e');
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userProvider.error ?? 'Failed to update profile'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile'),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Save',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingImage
                              ? null
                              : _showImagePickerOptions,
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage: _selectedImage != null
                                ? FileImage(File(_selectedImage!.path))
                                : (user.avatar != null
                                          ? NetworkImage(user.avatar!)
                                          : null)
                                      as ImageProvider?,
                            backgroundColor: colors.surfaceContainerHighest,
                            child: _isUploadingImage
                                ? const CircularProgressIndicator()
                                : (_selectedImage == null && user.avatar == null
                                      ? Icon(
                                          Icons.person,
                                          size: 60,
                                          color: colors.onSurfaceVariant,
                                        )
                                      : null),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploadingImage
                                ? null
                                : _showImagePickerOptions,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surface,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: colors.onPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        if (_selectedImage != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                  _newAvatarUrl = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colors.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: colors.onError,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedImage != null
                        ? 'New photo selected'
                        : 'Tap to change profile picture',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _selectedImage != null ? colors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Fields
                  _buildInputField(
                    context,
                    label: 'Display Name',
                    controller: _displayNameController,
                    icon: Icons.person,
                    hint: 'Your display name',
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    context,
                    label: 'Username',
                    controller: _usernameController,
                    icon: Icons.alternate_email,
                    hint: 'username',
                    prefix: '@',
                    enabled: false, // Username usually restricted
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    context,
                    label: 'Bio',
                    controller: _bioController,
                    icon: Icons.info_outline,
                    hint: 'Tell us about yourself...',
                    maxLines: 4,
                    maxLength: 160,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    context,
                    label: 'Email',
                    controller: _emailController,
                    icon: Icons.email,
                    hint: 'your@email.com',
                    enabled: false,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    context,
                    label: 'Phone (Optional)',
                    controller: _phoneController,
                    icon: Icons.phone,
                    hint: '+1 (555) 123-4567',
                  ),
                  const SizedBox(height: 32),

                  // Options
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        _buildOptionTile(
                          context,
                          icon: Icons.verified_user,
                          title: 'Verification Status',
                          subtitle: user.isVerified
                              ? 'Verified Human'
                              : 'Not Verified',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HumanVerificationScreen(
                                  onVerify: () => Navigator.pop(context),
                                  onPhoneVerify: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PhoneVerificationScreen(
                                          onVerify: () =>
                                              Navigator.pop(context),
                                          onBack: () => Navigator.pop(context),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          trailing: Icon(
                            user.isVerified
                                ? Icons.check_circle
                                : Icons.info_outline,
                            color: user.isVerified
                                ? Colors.green
                                : colors.secondary,
                          ),
                        ),
                        Divider(color: colors.outlineVariant, height: 24),
                        _buildOptionTile(
                          context,
                          icon: Icons.gavel,
                          title: 'Appeal Status',
                          subtitle: 'Dispute restrictions or rejections',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AppealProfileScreen(),
                              ),
                            );
                          },
                          trailing: Icon(
                            Icons.chevron_right,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Divider(color: colors.outlineVariant, height: 24),
                        _buildOptionTile(
                          context,
                          icon: Icons.link,
                          title: 'Social Links',
                          subtitle: 'Connect your social media',
                          onTap: () => _showSocialLinksSheet(),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showSocialLinksSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(sheetContext).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              'Social Links',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your social media profiles to your bio.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            _buildLinkInput(
              Icons.link,
              'Website',
              'https://yourwebsite.com',
              _websiteController,
            ),
            const SizedBox(height: 16),
            _buildLinkInput(
              Icons.alternate_email,
              'Twitter / X',
              '@username',
              _twitterController,
            ),
            const SizedBox(height: 16),
            _buildLinkInput(
              Icons.camera_alt_outlined,
              'Instagram',
              'username',
              _instagramController,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Save Links',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkInput(
    IconData icon,
    String label,
    String hint,
    TextEditingController controller,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: hint,
            filled: true,
            fillColor: colors.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? prefix,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Container(
          decoration: BoxDecoration(
            color: enabled ? colors.surface : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            maxLength: maxLength,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodySmall,
              prefixIcon: Icon(icon, size: 20),
              prefixText: prefix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
