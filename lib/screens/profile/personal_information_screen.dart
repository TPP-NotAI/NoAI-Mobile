import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../config/app_colors.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;

  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AuthProvider>().currentUser;
    _firstNameController = TextEditingController(
      text: currentUser?.displayName ?? '',
    );
    _lastNameController = TextEditingController(
      text: currentUser?.username ?? '',
    );
    _emailController = TextEditingController(text: currentUser?.email ?? '');
    _phoneController = TextEditingController(text: currentUser?.phone ?? '');
    _bioController = TextEditingController(text: currentUser?.bio ?? '');
    _locationController = TextEditingController(
      text: currentUser?.verifiedHuman ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final updates = <String, dynamic>{
        'display_name': _firstNameController.text.trim(),
        'bio': _bioController.text.trim(),
        // Note: lastName and location are mapped to username and verified status for display,
        // usually these wouldn't be directly editable like this.
      };

      final success = await userProvider.updateProfile(user.id, updates);

      if (success) {
        await authProvider.reloadCurrentUser();
        if (mounted) {
          setState(() {
            _isEditing = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Personal information updated'.tr(context))),
          );
        }
      } else {
        throw Exception(userProvider.error ?? 'Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating information: $e'.tr(context))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text('Personal Information'.tr(context),
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: Text('Edit'.tr(context),
                style: TextStyle(color: AppColors.primary, fontSize: 16),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoSection(scheme, 'Basic Information', [
            _buildTextField(
              label: 'First Name',
              controller: _firstNameController,
              enabled: _isEditing,
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Last Name',
              controller: _lastNameController,
              enabled: _isEditing,
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Email',
              controller: _emailController,
              enabled: _isEditing,
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Phone',
              controller: _phoneController,
              enabled: _isEditing,
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection(scheme, 'Profile Details', [
            _buildTextField(
              label: 'Bio',
              controller: _bioController,
              enabled: _isEditing,
              icon: Icons.description,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Location',
              controller: _locationController,
              enabled: _isEditing,
              icon: Icons.location_on,
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoCard(
            scheme,
            'Username',
            '@${currentUser?.username ?? 'N/A'}',
            Icons.account_circle,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            scheme,
            'Member Since',
            _formatDate(currentUser?.createdAt),
            Icons.calendar_today,
          ),
          const SizedBox(height: 24),
          if (_isEditing)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text('Save Changes'.tr(context)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    ColorScheme scheme,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: scheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: enabled
            ? scheme.background
            : scheme.surface.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.3)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    ColorScheme scheme,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.month}/${date.day}/${date.year}';
  }
}


