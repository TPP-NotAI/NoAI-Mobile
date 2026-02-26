import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../l10n/app_localizations.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const List<String> _countries = [
    'Afghanistan',
    'Albania',
    'Algeria',
    'Andorra',
    'Angola',
    'Argentina',
    'Armenia',
    'Australia',
    'Austria',
    'Azerbaijan',
    'Bahrain',
    'Bangladesh',
    'Belarus',
    'Belgium',
    'Belize',
    'Benin',
    'Bhutan',
    'Bolivia',
    'Bosnia and Herzegovina',
    'Botswana',
    'Brazil',
    'Brunei',
    'Bulgaria',
    'Burkina Faso',
    'Burundi',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Cape Verde',
    'Central African Republic',
    'Chad',
    'Chile',
    'China',
    'Colombia',
    'Comoros',
    'Congo',
    'Costa Rica',
    'Croatia',
    'Cuba',
    'Cyprus',
    'Czech Republic',
    'Denmark',
    'Djibouti',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Equatorial Guinea',
    'Eritrea',
    'Estonia',
    'Eswatini',
    'Ethiopia',
    'Finland',
    'France',
    'Gabon',
    'Gambia',
    'Georgia',
    'Germany',
    'Ghana',
    'Greece',
    'Guatemala',
    'Guinea',
    'Guyana',
    'Haiti',
    'Honduras',
    'Hungary',
    'Iceland',
    'India',
    'Indonesia',
    'Iran',
    'Iraq',
    'Ireland',
    'Israel',
    'Italy',
    'Jamaica',
    'Japan',
    'Jordan',
    'Kazakhstan',
    'Kenya',
    'Kuwait',
    'Kyrgyzstan',
    'Laos',
    'Latvia',
    'Lebanon',
    'Lesotho',
    'Liberia',
    'Libya',
    'Lithuania',
    'Luxembourg',
    'Madagascar',
    'Malawi',
    'Malaysia',
    'Maldives',
    'Mali',
    'Malta',
    'Mauritania',
    'Mauritius',
    'Mexico',
    'Moldova',
    'Mongolia',
    'Montenegro',
    'Morocco',
    'Mozambique',
    'Myanmar',
    'Namibia',
    'Nepal',
    'Netherlands',
    'New Zealand',
    'Nicaragua',
    'Niger',
    'Nigeria',
    'North Korea',
    'North Macedonia',
    'Norway',
    'Oman',
    'Pakistan',
    'Panama',
    'Papua New Guinea',
    'Paraguay',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Qatar',
    'Romania',
    'Russia',
    'Rwanda',
    'Saudi Arabia',
    'Senegal',
    'Serbia',
    'Sierra Leone',
    'Singapore',
    'Slovakia',
    'Slovenia',
    'Somalia',
    'South Africa',
    'South Korea',
    'South Sudan',
    'Spain',
    'Sri Lanka',
    'Sudan',
    'Suriname',
    'Sweden',
    'Switzerland',
    'Syria',
    'Taiwan',
    'Tajikistan',
    'Tanzania',
    'Thailand',
    'Togo',
    'Trinidad and Tobago',
    'Tunisia',
    'Turkey',
    'Turkmenistan',
    'Uganda',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Uruguay',
    'Uzbekistan',
    'Venezuela',
    'Vietnam',
    'Yemen',
    'Zambia',
    'Zimbabwe',
  ];

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _twitterController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final SupabaseService _supabase = SupabaseService();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  XFile? _selectedImage;
  String? _newAvatarUrl;
  DateTime? _selectedBirthDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
          _countryController.text =
              user.countryOfResidence ?? user.location ?? '';
          _selectedBirthDate = user.birthDate;
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
    _countryController.dispose();
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
                _editProfileText(context, 'changeProfilePicture'),
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
                title: Text(_editProfileText(context, 'takePhoto')),
                subtitle: Text(_editProfileText(context, 'useCamera')),
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
                title: Text(_editProfileText(context, 'chooseFromGallery')),
                subtitle: Text(
                  _editProfileText(context, 'selectExistingPhoto'),
                ),
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
                  title: Text(_editProfileText(context, 'removePhoto')),
                  subtitle: Text(
                    _editProfileText(context, 'deleteCurrentSelection'),
                  ),
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

      setState(() {
        _selectedImage = image;
        _newAvatarUrl = null; // Clear any previously uploaded URL
      });
    } on PlatformException catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) {
        String message = _editProfileText(
          context,
          source == ImageSource.camera
              ? 'failedAccessCamera'
              : 'failedAccessPhotos',
        );
        if (e.code == 'camera_access_denied' ||
            e.code == 'photo_access_denied') {
          message = _editProfileText(
            context,
            source == ImageSource.camera
                ? 'permissionDeniedCamera'
                : 'permissionDeniedPhotos',
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: _editProfileText(context, 'settings'),
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
            content: Text('${_editProfileText(context, 'failedPickImage')}: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
            content: Text('${_editProfileText(context, 'failedUploadImage')}: $e',
            ),
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
      'location': _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
      'birth_date': _selectedBirthDate == null
          ? null
          : _formatDateForDb(_selectedBirthDate!),
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
              SnackBar(
                content: Text(
                  _editProfileText(context, 'profileCompleteReward'),
                ),
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
          SnackBar(
            content: Text(
              _editProfileText(context, 'profileUpdatedSuccessfully'),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userProvider.error ??
                  _editProfileText(context, 'failedUpdateProfile'),
            ),
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
        title: Text(_editProfileText(context, 'editProfile')),
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
                _editProfileText(context, 'save'),
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
                        ? _editProfileText(context, 'newPhotoSelected')
                        : _editProfileText(context, 'tapChangeProfilePicture'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _selectedImage != null ? colors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Fields
                  _buildInputField(
                    context,
                    label: _editProfileText(context, 'displayName'),
                    controller: _displayNameController,
                    icon: Icons.person,
                    hint: _editProfileText(context, 'yourDisplayName'),
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    context,
                    label: _editProfileText(context, 'username'),
                    controller: _usernameController,
                    icon: Icons.alternate_email,
                    hint: 'username',
                    prefix: '@',
                    enabled: false, // Username usually restricted
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    context,
                    label: _editProfileText(context, 'bio'),
                    controller: _bioController,
                    icon: Icons.info_outline,
                    hint: 'Tell us about yourself...',
                    maxLines: 4,
                    maxLength: 160,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    context,
                    label: _editProfileText(context, 'email'),
                    controller: _emailController,
                    icon: Icons.email,
                    hint: 'your@email.com',
                    enabled: false,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    context,
                    label: _editProfileText(context, 'phoneOptional'),
                    controller: _phoneController,
                    icon: Icons.phone,
                    hint: '+1 (555) 123-4567',
                  ),
                  const SizedBox(height: 20),
                  _buildCountryField(context),
                  const SizedBox(height: 20),
                  _buildDateField(
                    context,
                    label: _editProfileText(context, 'dateOfBirth'),
                    icon: Icons.cake_outlined,
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
                          title: _editProfileText(
                            context,
                            'verificationStatus',
                          ),
                          subtitle: user.isVerified
                              ? _editProfileText(context, 'verifiedHuman')
                              : _editProfileText(context, 'notVerified'),
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
                          title: _editProfileText(context, 'appealStatus'),
                          subtitle: _editProfileText(
                            context,
                            'appealStatusSubtitle',
                          ),
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
                          title: _editProfileText(context, 'socialLinks'),
                          subtitle: _editProfileText(
                            context,
                            'connectSocialMedia',
                          ),
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

  String _formatDateForDb(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatDateForDisplay(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthDate ?? DateTime(now.year - 18, 1, 1);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );

    if (pickedDate != null && mounted) {
      setState(() => _selectedBirthDate = pickedDate);
    }
  }

  Future<void> _showCountryPicker() async {
    final colors = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        var filteredCountries = List<String>.from(_countries);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 12,
                ),
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
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: _editProfileText(context, 'searchCountry'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        final query = value.trim().toLowerCase();
                        setSheetState(() {
                          filteredCountries = _countries
                              .where(
                                (country) =>
                                    country.toLowerCase().contains(query),
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: ListView.builder(
                        itemCount: filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country = filteredCountries[index];
                          return ListTile(
                            title: Text(country),
                            trailing: _countryController.text == country
                                ? Icon(Icons.check, color: colors.primary)
                                : null,
                            onTap: () {
                              setState(() => _countryController.text = country);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCountryField(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            _editProfileText(context, 'countryOfResidence'),
            style: theme.textTheme.labelMedium,
          ),
        ),
        InkWell(
          onTap: _showCountryPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.public, size: 20, color: colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _countryController.text.isEmpty
                        ? _editProfileText(context, 'selectCountry')
                        : _countryController.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _countryController.text.isEmpty
                          ? theme.textTheme.bodySmall?.color
                          : colors.onSurface,
                    ),
                  ),
                ),
                if (_countryController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _countryController.clear()),
                    tooltip: _editProfileText(context, 'clearCountry'),
                  ),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required String label,
    required IconData icon,
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
        InkWell(
          onTap: _selectBirthDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedBirthDate == null
                        ? _editProfileText(context, 'selectDateOfBirth')
                        : _formatDateForDisplay(_selectedBirthDate!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _selectedBirthDate == null
                          ? theme.textTheme.bodySmall?.color
                          : colors.onSurface,
                    ),
                  ),
                ),
                if (_selectedBirthDate != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _selectedBirthDate = null),
                    tooltip: _editProfileText(context, 'clearDate'),
                  ),
              ],
            ),
          ),
        ),
      ],
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
              _editProfileText(context, 'socialLinks'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _editProfileText(context, 'socialLinksDescription'),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            _buildLinkInput(
              Icons.link,
              _editProfileText(context, 'website'),
              'https://yourwebsite.com',
              _websiteController,
            ),
            const SizedBox(height: 16),
            _buildLinkInput(
              Icons.alternate_email,
              _editProfileText(context, 'twitterX'),
              '@username',
              _twitterController,
            ),
            const SizedBox(height: 16),
            _buildLinkInput(
              Icons.camera_alt_outlined,
              _editProfileText(context, 'instagram'),
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
                child: Text(
                  _editProfileText(context, 'saveLinks'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
            textCapitalization: TextCapitalization.sentences,
            enableSuggestions: true,
            autocorrect: true,
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

  String _editProfileText(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context);
    switch (key) {
      case 'editProfile':
        return l10n?.editProfile ?? 'Edit Profile';
      case 'notVerified':
        return l10n?.notVerified ?? 'Not Verified';
      case 'verificationStatus':
        return 'Verification Status';
      case 'settings':
        return 'Settings';
      case 'save':
        return 'Save';
      case 'changeProfilePicture':
        return 'Change Profile Picture';
      case 'takePhoto':
        return 'Take a Photo';
      case 'useCamera':
        return 'Use your camera';
      case 'chooseFromGallery':
        return 'Choose from Gallery';
      case 'selectExistingPhoto':
        return 'Select an existing photo';
      case 'removePhoto':
        return 'Remove Photo';
      case 'deleteCurrentSelection':
        return 'Delete current selection';
      case 'failedAccessCamera':
        return 'Failed to access camera';
      case 'failedAccessPhotos':
        return 'Failed to access photos';
      case 'permissionDeniedCamera':
        return 'Permission denied. Please enable camera access in your device settings.';
      case 'permissionDeniedPhotos':
        return 'Permission denied. Please enable photos access in your device settings.';
      case 'failedPickImage':
        return 'Failed to pick image';
      case 'failedUploadImage':
        return 'Failed to upload image';
      case 'profileCompleteReward':
        return 'Profile complete! Earned 20 ROO';
      case 'profileUpdatedSuccessfully':
        return 'Profile updated successfully!';
      case 'failedUpdateProfile':
        return 'Failed to update profile';
      case 'newPhotoSelected':
        return 'New photo selected';
      case 'tapChangeProfilePicture':
        return 'Tap to change profile picture';
      case 'displayName':
        return 'Display Name';
      case 'username':
        return 'Username';
      case 'bio':
        return 'Bio';
      case 'email':
        return 'Email';
      case 'yourDisplayName':
        return 'Your display name';
      case 'phoneOptional':
        return 'Phone (Optional)';
      case 'dateOfBirth':
        return 'Date of Birth';
      case 'verifiedHuman':
        return 'Verified Human';
      case 'appealStatus':
        return 'Appeal Status';
      case 'appealStatusSubtitle':
        return 'Dispute restrictions or rejections';
      case 'socialLinks':
        return 'Social Links';
      case 'connectSocialMedia':
        return 'Connect your social media';
      case 'searchCountry':
        return 'Search country...';
      case 'countryOfResidence':
        return 'Country of Residence';
      case 'selectCountry':
        return 'Select country';
      case 'clearCountry':
        return 'Clear country';
      case 'selectDateOfBirth':
        return 'Select your date of birth';
      case 'clearDate':
        return 'Clear date';
      case 'socialLinksDescription':
        return 'Add your social media profiles to your bio.';
      case 'website':
        return 'Website';
      case 'twitterX':
        return 'Twitter / X';
      case 'instagram':
        return 'Instagram';
      case 'saveLinks':
        return 'Save Links';
      default:
        return key;
    }
  }
}
