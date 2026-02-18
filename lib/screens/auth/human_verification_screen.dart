import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../services/veriff_service.dart';
import '../../services/kyc_verification_service.dart';
import '../../utils/responsive_extensions.dart';
import 'package:url_launcher/url_launcher.dart';

enum VerificationMethod { phone, veriff }

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

class _HumanVerificationScreenState extends State<HumanVerificationScreen>
    with WidgetsBindingObserver {
  VerificationMethod? _selectedMethod;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSessionActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the app resumes from the browser, check if there's a pending session.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isSessionActive) {
      _checkVerificationResult();
    }
  }

  void _selectMethod(VerificationMethod method) {
    setState(() {
      _selectedMethod = method;
      _statusMessage = null;
    });
  }

  Future<void> _proceedWithVerification() async {
    if (_selectedMethod == null) return;

    if (_selectedMethod == VerificationMethod.phone) {
      widget.onPhoneVerify();
      return;
    }

    // Veriff flow
    await _startVeriffVerification();
  }

  Future<void> _startVeriffVerification() async {
    if (_isLoading) return;

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Creating verification session...';
      });

      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      final displayName = authProvider.currentUser?.displayName ?? '';

      if (userId == null) {
        throw Exception('User not found. Please log in again.');
      }

      // Split display name into first/last
      final nameParts = displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : null;
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : null;

      // Create Veriff session via Edge Function
      final veriffService = VeriffService();
      final session = await veriffService.createSession(
        userId: userId,
        firstName: firstName,
        lastName: lastName,
      );

      if (!mounted) return;

      // Mark session as active to triggering polling on return
      _isSessionActive = true;

      setState(() => _statusMessage = 'Opening secure verification window...');

      // Launch in-app so user stays inside the app context.
      final url = Uri.parse(session.sessionUrl);
      final launched = await launchUrl(url, mode: LaunchMode.inAppWebView);

      if (!launched) {
        throw Exception(
          'Could not open verification window. Please try again.',
        );
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Complete verification, then return to continue.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _isSessionActive = false;
        setState(() {
          _statusMessage = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkVerificationResult() async {
    if (!_isSessionActive) return;

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Checking verification status...';
      });

      final authProvider = context.read<AuthProvider>();

      // Poll the profile for updates (expects Webhook to update DB)
      bool isVerified = false;
      for (int i = 0; i < 10; i++) {
        // Poll 10 times (approx 30s)
        await authProvider.reloadCurrentUser();

        // Re-read status after reload
        final currentUser = authProvider.currentUser;
        if (currentUser?.verifiedHuman == 'verified') {
          isVerified = true;
          break;
        }

        if (!mounted) return;

        // Wait before next poll
        await Future.delayed(const Duration(seconds: 3));
      }

      if (!mounted) return;

      _isSessionActive = false;

      if (isVerified) {
        // Double check cache
        final userId = authProvider.currentUser?.id;
        if (userId != null) {
          KycVerificationService().setVerified(userId, true);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Identity verified successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onVerify();
        }
      } else {
        // Timeout or not verified yet
        setState(() {
          _statusMessage = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification status not yet updated. It may take a few minutes. Check back later.',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking result: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
      final auth = context.read<AuthProvider>();
      await auth.signOut();
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
                        SizedBox(
                          width: 48.responsive(context, min: 40, max: 56),
                        ),

                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.standard.responsive(context),
                          vertical: AppSpacing.small.responsive(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: AppSpacing.responsiveRadius(
                            context,
                            AppSpacing.radiusMedium,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: AppTypography.responsiveIconSize(
                                context,
                                16,
                              ),
                              color: AppColors.primary,
                            ),
                            SizedBox(
                              width: AppSpacing.extraSmall.responsive(context),
                            ),
                            Text(
                              'IDENTITY VERIFICATION',
                              style: TextStyle(
                                fontSize: AppTypography.responsiveFontSize(
                                  context,
                                  10,
                                ),
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
                        context,
                        AppTypography.largeHeading,
                      ),
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: AppSpacing.standard.responsive(context)),

                  Text(
                    'ROOVERSE uses Veriff for secure identity verification. This ensures our community remains 100% human.',
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.base,
                      ),
                      color: scheme.onSurface.withOpacity(0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 40.responsive(context, min: 32, max: 48)),

                  _buildOptions(context),

                  SizedBox(height: AppSpacing.triple.responsive(context)),

                  // Status message
                  if (_statusMessage != null) ...[
                    Container(
                      padding: AppSpacing.responsiveAll(
                        context,
                        AppSpacing.standard,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: AppSpacing.responsiveRadius(
                          context,
                          AppSpacing.radiusMedium,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            SizedBox(
                              width: 16.responsive(context),
                              height: 16.responsive(context),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.info_outline,
                              size: AppTypography.responsiveIconSize(
                                context,
                                16,
                              ),
                              color: AppColors.primary,
                            ),
                          SizedBox(
                            width: AppSpacing.standard.responsive(context),
                          ),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: AppTypography.responsiveFontSize(
                                  context,
                                  AppTypography.small,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.standard.responsive(context)),
                  ],

                  // Check result button (when waiting for user to return)
                  if (_isSessionActive && !_isLoading)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: AppSpacing.standard.responsive(context),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48.responsive(context, min: 40, max: 56),
                        child: OutlinedButton.icon(
                          onPressed: _checkVerificationResult,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check Verification Status'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppSpacing.responsiveRadius(
                                context,
                                30,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

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
      child: Icon(
        Icons.fingerprint,
        size: AppTypography.responsiveIconSize(context, 48),
        color: Colors.white,
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Column(
      children: [
        _buildVerificationOption(
          context,
          method: VerificationMethod.veriff,
          icon: Icons.badge_outlined,
          title: 'ID Verification (Veriff)',
          subtitle: 'Passport, License, or National ID + Selfie',
          badge: 'SECURE',
          badgeColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildActionButton(ColorScheme scheme) {
    String label = 'Select a Method';
    if (_selectedMethod != null) {
      if (_selectedMethod == VerificationMethod.phone) {
        label = 'Continue with Phone';
      } else {
        label = 'Start Veriff Verification';
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
                        context,
                        AppTypography.smallHeading,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: AppSpacing.mediumSmall.responsive(context)),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: AppTypography.responsiveIconSize(context, 20),
                  ),
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
        borderRadius: AppSpacing.responsiveRadius(
          context,
          AppSpacing.radiusExtraLarge,
        ),
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
                  'Powered by Veriff',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.base,
                    ),
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(height: AppSpacing.extraSmall.responsive(context)),
                Text(
                  'Your data is encrypted and processing is handled securely by Supabase and Veriff.',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.extraSmall,
                    ),
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
          borderRadius: AppSpacing.responsiveRadius(
            context,
            AppSpacing.radiusModal,
          ),
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
                borderRadius: AppSpacing.responsiveRadius(
                  context,
                  AppSpacing.radiusLarge,
                ),
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
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: AppTypography.responsiveFontSize(
                              context,
                              AppTypography.smallHeading,
                            ),
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.primary
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        SizedBox(
                          width: AppSpacing.mediumSmall.responsive(context),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.small.responsive(context),
                            vertical:
                                AppSpacing.extraSmall.responsive(context) / 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary)
                                .withOpacity(0.1),
                            borderRadius: AppSpacing.responsiveRadius(
                              context,
                              AppSpacing.radiusSmall,
                            ),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: AppTypography.responsiveFontSize(
                                context,
                                9,
                              ),
                              fontWeight: FontWeight.w900,
                              color: badgeColor ?? AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(
                    height: AppSpacing.extraSmall.responsive(context) / 2,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.small,
                      ),
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
