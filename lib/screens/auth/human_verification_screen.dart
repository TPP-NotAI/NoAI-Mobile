import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

enum VerificationMethod { phone, idDocument, selfie }

class HumanVerificationScreen extends StatefulWidget {
  final VoidCallback onVerify;
  final VoidCallback onPhoneVerify;
  final VoidCallback? onBack;

  const HumanVerificationScreen({
    super.key,
    required this.onVerify,
    required this.onPhoneVerify,
    this.onBack,
  });

  @override
  State<HumanVerificationScreen> createState() =>
      _HumanVerificationScreenState();
}

class _HumanVerificationScreenState extends State<HumanVerificationScreen> {
  VerificationMethod? _selectedMethod;
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  void _selectMethod(VerificationMethod method) {
    setState(() {
      _selectedMethod = method;
      _selectedImage = null; // Reset image when switching methods
    });
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: type == 'selfie' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _proceedWithVerification() async {
    if (_selectedMethod == null) return;

    if (_selectedMethod == VerificationMethod.phone) {
      widget.onPhoneVerify();
      return;
    }

    if (_selectedImage == null) {
      _pickImage(
        _selectedMethod == VerificationMethod.idDocument
            ? 'id_document'
            : 'selfie',
      );
      return;
    }

    await _handleImageVerification(
      _selectedMethod == VerificationMethod.idDocument
          ? 'id_document'
          : 'selfie',
    );
  }

  Future<void> _handleImageVerification(String type) async {
    if (_selectedImage == null) return;

    try {
      setState(() => _isLoading = true);

      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        throw Exception('User not found. Please log in again.');
      }

      // Upload to Supabase Storage
      final fileExt = _selectedImage!.path.split('.').last;
      final fileName =
          '${userId}_${type}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$fileName';

      // Ensure 'verification_docs' bucket exists and is public/private as per security
      await SupabaseService().client.storage
          .from('verification_docs')
          .upload(
            filePath,
            _selectedImage!,
            fileOptions: const FileOptions(upsert: true),
          );

      // Update verification status
      final success = await authProvider.updateVerificationStatus(type);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onVerify();
        }
      } else {
        throw Exception('Failed to update verification status in database.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? You will need to complete verification later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Gradient background
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.onBack != null || Navigator.canPop(context))
                        IconButton(
                          onPressed: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        )
                      else
                        const SizedBox(width: 48),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'IDENTITY VERIFICATION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: _handleLogout,
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.red,
                          size: 20,
                        ),
                        tooltip: 'Sign Out',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Illustration/Icon
                  _buildTopIcon(),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Verify You\'re Human',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'NOAI is a human-only community. To start earning RooCoin and posting, we need to verify your identity.',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface.withOpacity(0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  if (_selectedImage != null)
                    _buildImagePreview(scheme)
                  else
                    _buildOptions(context),

                  const SizedBox(height: 32),

                  // Action button
                  _buildActionButton(scheme),

                  const SizedBox(height: 24),

                  // Trust Info
                  _buildTrustInfo(scheme),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIcon() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.fingerprint, size: 48, color: Colors.white),
    );
  }

  Widget _buildImagePreview(ColorScheme scheme) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.5),
              width: 2,
            ),
            image: DecorationImage(
              image: FileImage(_selectedImage!),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () => setState(() => _selectedImage = null),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedMethod == VerificationMethod.idDocument
                            ? 'ID Captured'
                            : 'Selfie Captured',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Make sure your details are clear and legible.',
          style: TextStyle(
            color: scheme.onSurface.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Column(
      children: [
        _buildVerificationOption(
          context,
          method: VerificationMethod.phone,
          icon: Icons.phone_android,
          title: 'Phone Verification',
          subtitle: 'Instant verify via SMS code',
          badge: 'FASTEST',
          badgeColor: AppColors.primary,
        ),
        const SizedBox(height: 16),
        _buildVerificationOption(
          context,
          method: VerificationMethod.idDocument,
          icon: Icons.badge_outlined,
          title: 'ID Document',
          subtitle: 'Passport, License, or National ID',
        ),
        const SizedBox(height: 16),
        _buildVerificationOption(
          context,
          method: VerificationMethod.selfie,
          icon: Icons.face_retouching_natural,
          title: 'Selfie Verification',
          subtitle: 'Liveness check via your camera',
        ),
      ],
    );
  }

  Widget _buildActionButton(ColorScheme scheme) {
    String label = 'Select a Method';
    if (_selectedMethod != null) {
      if (_selectedMethod == VerificationMethod.phone) {
        label = 'Continue with Phone';
      } else if (_selectedImage == null) {
        label = _selectedMethod == VerificationMethod.idDocument
            ? 'Capture ID'
            : 'Take Selfie';
      } else {
        label = 'Submit Verification';
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _selectedMethod != null && !_isLoading
            ? _proceedWithVerification
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildTrustInfo(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy First',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your data is encrypted and used only for verification purposes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationOption(
    BuildContext context, {
    required VerificationMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedMethod == method;

    return GestureDetector(
      onTap: () => _selectMethod(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : scheme.outline.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : scheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 26,
                color: isSelected
                    ? Colors.white
                    : scheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.primary
                              : scheme.onSurface,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: badgeColor ?? AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : scheme.outline.withOpacity(0.2),
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
