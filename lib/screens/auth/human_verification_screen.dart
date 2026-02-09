import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/responsive_extensions.dart';

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
              top: -100.responsive(context),
              right: -100.responsive(context),
              child: Container(
                width: 300.responsive(context, min: 250, max: 350),
                height: 300.responsive(context, min: 250, max: 350),
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
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.double_.responsive(context),
              ),
              child: Column(
                children: [
                  SizedBox(height: AppSpacing.double_.responsive(context)),

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
                        SizedBox(width: 48.responsive(context, min: 40, max: 56)),

                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.standard.responsive(context),
                          vertical: AppSpacing.small.responsive(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: AppSpacing.responsiveRadius(
                              context, AppSpacing.radiusMedium),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: AppTypography.responsiveIconSize(context, 16),
                              color: AppColors.primary,
                            ),
                            SizedBox(
                                width: AppSpacing.extraSmall.responsive(context)),
                            Text(
                              'IDENTITY VERIFICATION',
                              style: TextStyle(
                                fontSize: AppTypography.responsiveFontSize(
                                    context, 10),
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
                        icon: Icon(
                          Icons.logout,
                          color: Colors.red,
                          size: AppTypography.responsiveIconSize(context, 20),
                        ),
                        tooltip: 'Sign Out',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 40.responsive(context, min: 32, max: 48)),

                  // Illustration/Icon
                  _buildTopIcon(),

                  SizedBox(height: AppSpacing.triple.responsive(context)),

                  // Title
                  Text(
                    'Verify You\'re Human',
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                          context, AppTypography.largeHeading),
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: AppSpacing.standard.responsive(context)),

                  Text(
                    'ROOVERSE is a human-only community. To start earning RooCoin and posting, we need to verify your identity.',
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                          context, AppTypography.base),
                      color: scheme.onSurface.withOpacity(0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 40.responsive(context, min: 32, max: 48)),

                  if (_selectedImage != null)
                    _buildImagePreview(scheme)
                  else
                    _buildOptions(context),

                  SizedBox(height: AppSpacing.triple.responsive(context)),

                  // Action button
                  _buildActionButton(scheme),

                  SizedBox(height: AppSpacing.double_.responsive(context)),

                  // Trust Info
                  _buildTrustInfo(scheme),

                  SizedBox(height: AppSpacing.triple.responsive(context)),
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
      width: 96.responsive(context, min: 80, max: 112),
      height: 96.responsive(context, min: 80, max: 112),
      decoration: BoxDecoration(
        borderRadius: AppSpacing.responsiveRadius(context, 32),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 30.responsive(context),
            offset: Offset(0, 10.responsive(context)),
          ),
        ],
      ),
      child: Icon(Icons.fingerprint,
          size: AppTypography.responsiveIconSize(context, 48),
          color: Colors.white),
    );
  }

  Widget _buildImagePreview(ColorScheme scheme) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 240.responsive(context, min: 200, max: 280),
          decoration: BoxDecoration(
            borderRadius:
                AppSpacing.responsiveRadius(context, AppSpacing.radiusModal),
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
                top: AppSpacing.standard.responsive(context),
                right: AppSpacing.standard.responsive(context),
                child: IconButton(
                  onPressed: () => setState(() => _selectedImage = null),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                ),
              ),
              Positioned(
                bottom: AppSpacing.standard.responsive(context),
                left: AppSpacing.standard.responsive(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.standard.responsive(context),
                    vertical: AppSpacing.small.responsive(context),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius:
                        AppSpacing.responsiveRadius(context, AppSpacing.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: AppTypography.responsiveIconSize(context, 16),
                      ),
                      SizedBox(width: AppSpacing.mediumSmall.responsive(context)),
                      Text(
                        _selectedMethod == VerificationMethod.idDocument
                            ? 'ID Captured'
                            : 'Selfie Captured',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppTypography.responsiveFontSize(
                              context, AppTypography.extraSmall),
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
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        Text(
          'Make sure your details are clear and legible.',
          style: TextStyle(
            color: scheme.onSurface.withOpacity(0.6),
            fontSize: AppTypography.responsiveFontSize(
                context, AppTypography.small),
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
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        _buildVerificationOption(
          context,
          method: VerificationMethod.idDocument,
          icon: Icons.badge_outlined,
          title: 'ID Document',
          subtitle: 'Passport, License, or National ID',
        ),
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
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
      height: 60.responsive(context, min: 52, max: 68),
      child: ElevatedButton(
        onPressed: _selectedMethod != null && !_isLoading
            ? _proceedWithVerification
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.responsiveRadius(context, 30),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
        ),
        child: _isLoading
            ? SizedBox(
                height: 24.responsive(context, min: 20, max: 28),
                width: 24.responsive(context, min: 20, max: 28),
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                          context, AppTypography.smallHeading),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: AppSpacing.mediumSmall.responsive(context)),
                  Icon(Icons.arrow_forward_rounded,
                      size: AppTypography.responsiveIconSize(context, 20)),
                ],
              ),
      ),
    );
  }

  Widget _buildTrustInfo(ColorScheme scheme) {
    return Container(
      padding: AppSpacing.responsiveAll(context, AppSpacing.largePlus),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius:
            AppSpacing.responsiveRadius(context, AppSpacing.radiusExtraLarge),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: AppSpacing.responsiveAll(context, AppSpacing.standard),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: AppTypography.responsiveIconSize(context, 24),
            ),
          ),
          SizedBox(width: AppSpacing.largePlus.responsive(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy First',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                        context, AppTypography.base),
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(height: AppSpacing.extraSmall.responsive(context)),
                Text(
                  'Your data is encrypted and used only for verification purposes.',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                        context, AppTypography.extraSmall),
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
        padding: AppSpacing.responsiveAll(context, AppSpacing.largePlus),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : scheme.surfaceContainerLow,
          borderRadius:
              AppSpacing.responsiveRadius(context, AppSpacing.radiusModal),
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
                blurRadius: 12.responsive(context),
                offset: Offset(0, 4.responsive(context)),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52.responsive(context, min: 44, max: 60),
              height: 52.responsive(context, min: 44, max: 60),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : scheme.surface,
                borderRadius:
                    AppSpacing.responsiveRadius(context, AppSpacing.radiusLarge),
              ),
              child: Icon(
                icon,
                size: AppTypography.responsiveIconSize(context, 26),
                color: isSelected
                    ? Colors.white
                    : scheme.onSurface.withOpacity(0.6),
              ),
            ),
            SizedBox(width: AppSpacing.largePlus.responsive(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: AppTypography.responsiveFontSize(
                              context, AppTypography.smallHeading),
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.primary
                              : scheme.onSurface,
                        ),
                      ),
                      if (badge != null) ...[
                        SizedBox(
                            width: AppSpacing.mediumSmall.responsive(context)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.small.responsive(context),
                            vertical: AppSpacing.extraSmall.responsive(context) /
                                2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary)
                                .withOpacity(0.1),
                            borderRadius: AppSpacing.responsiveRadius(
                                context, AppSpacing.radiusSmall),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: AppTypography.responsiveFontSize(
                                  context, 9),
                              fontWeight: FontWeight.w900,
                              color: badgeColor ?? AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppSpacing.extraSmall.responsive(context) / 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                          context, AppTypography.small),
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24.responsive(context, min: 20, max: 28),
              height: 24.responsive(context, min: 20, max: 28),
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
