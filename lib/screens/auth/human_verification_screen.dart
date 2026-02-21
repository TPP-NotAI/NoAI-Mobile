import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../services/didit_service.dart';
import '../../services/kyc_verification_service.dart';
import '../../utils/responsive_extensions.dart';

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
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSessionActive = false;
  bool _onVerifyCalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for realtime profile updates pushed by the Didit webhook.
    // AuthProvider already subscribes to Supabase Realtime on the profiles
    // table, so when verified_human changes to 'verified' we get notified here
    // and can call onVerify() without the user restarting the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().addListener(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_onVerifyCalled || !mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user?.verifiedHuman == 'verified') {
      _onVerifyCalled = true;
      widget.onVerify();
    }
  }

  /// When the app resumes from the browser, poll for the result.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isSessionActive) {
      _checkVerificationResult();
    }
  }

  Future<void> _startVerification() async {
    if (_isLoading) return;

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Creating verification session...';
      });

      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      final email = authProvider.currentUser?.email;

      if (userId == null) {
        throw Exception('User not found. Please log in again.');
      }

      final session = await DiditService().createSession(
        userId: userId,
        email: email,
      );

      if (!mounted) return;

      _isSessionActive = true;
      setState(() => _statusMessage = 'Opening secure verification window...');

      final url = Uri.parse(session.sessionUrl);
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!launched) {
        throw Exception('Could not open verification window. Please try again.');
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Complete verification in your browser, then return here.';
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

      bool isVerified = false;
      for (int i = 0; i < 10; i++) {
        await authProvider.reloadCurrentUser();
        if (authProvider.currentUser?.verifiedHuman == 'verified') {
          isVerified = true;
          break;
        }
        if (!mounted) return;
        await Future.delayed(const Duration(seconds: 3));
      }

      if (!mounted) return;

      _isSessionActive = false;

      if (isVerified) {
        final userId = authProvider.currentUser?.id;
        if (userId != null) {
          KycVerificationService().setVerified(userId, true);
        }
        setState(() {
          _statusMessage = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Identity verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        if (!_onVerifyCalled) {
          _onVerifyCalled = true;
          widget.onVerify();
        }
      } else {
        setState(() {
          _statusMessage = null;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification not yet complete. It may take a few minutes — check back soon.',
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking status: ${e.toString()}'),
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
            child: Text(AppLocalizations.of(context)!.cancel),
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
            // Subtle radial gradient background
            Positioned(
              top: -100.responsive(context),
              right: -100.responsive(context),
              child: Container(
                width: 300.responsive(context, min: 250, max: 350),
                height: 300.responsive(context, min: 250, max: 350),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
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

                  // ── Header row ─────────────────────────────────────
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
                            context,
                            AppSpacing.radiusMedium,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: AppTypography.responsiveIconSize(context, 16),
                              color: AppColors.primary,
                            ),
                            SizedBox(width: AppSpacing.extraSmall.responsive(context)),
                            Text(
                              'IDENTITY VERIFICATION',
                              style: TextStyle(
                                fontSize: AppTypography.responsiveFontSize(context, 10),
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
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 40.responsive(context, min: 32, max: 48)),

                  // ── Icon ───────────────────────────────────────────
                  _buildTopIcon(),

                  SizedBox(height: AppSpacing.triple.responsive(context)),

                  // ── Title ──────────────────────────────────────────
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
                    'ROOVERSE uses Didit for secure, AI-powered identity verification. This ensures our community remains 100% human.',
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.base,
                      ),
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 40.responsive(context, min: 32, max: 48)),

                  // ── Verification option card ────────────────────────
                  _buildOptionCard(scheme),

                  SizedBox(height: AppSpacing.triple.responsive(context)),

                  // ── Status message ─────────────────────────────────
                  if (_statusMessage != null) ...[
                    Container(
                      padding: AppSpacing.responsiveAll(context, AppSpacing.standard),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: AppSpacing.responsiveRadius(
                          context,
                          AppSpacing.radiusMedium,
                        ),
                      ),
                      child: Row(
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
                              size: AppTypography.responsiveIconSize(context, 16),
                              color: AppColors.primary,
                            ),
                          SizedBox(width: AppSpacing.standard.responsive(context)),
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

                  // ── Manual status check button ─────────────────────
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
                              borderRadius: AppSpacing.responsiveRadius(context, 30),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Primary action button ──────────────────────────
                  _buildActionButton(),

                  SizedBox(height: AppSpacing.double_.responsive(context)),

                  // ── Trust info ─────────────────────────────────────
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
            color: AppColors.primary.withValues(alpha: 0.35),
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

  Widget _buildOptionCard(ColorScheme scheme) {
    return Container(
      padding: AppSpacing.responsiveAll(context, AppSpacing.largePlus),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppSpacing.responsiveRadius(context, AppSpacing.radiusModal),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
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
              color: AppColors.primary,
              borderRadius: AppSpacing.responsiveRadius(context, AppSpacing.radiusLarge),
            ),
            child: Icon(
              Icons.badge_outlined,
              size: AppTypography.responsiveIconSize(context, 26),
              color: Colors.white,
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
                        'ID Verification',
                        style: TextStyle(
                          fontSize: AppTypography.responsiveFontSize(
                            context,
                            AppTypography.smallHeading,
                          ),
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.mediumSmall.responsive(context)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.small.responsive(context),
                        vertical: AppSpacing.extraSmall.responsive(context) / 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.responsiveRadius(
                          context,
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Text(
                        'AI-POWERED',
                        style: TextStyle(
                          fontSize: AppTypography.responsiveFontSize(context, 9),
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.extraSmall.responsive(context) / 2),
                Text(
                  'Passport, Driver\'s License, or National ID + Selfie',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(context, AppTypography.small),
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 60.responsive(context, min: 52, max: 68),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _startVerification,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.responsiveRadius(context, 30),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
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
                    'Start Verification',
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
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppSpacing.responsiveRadius(context, AppSpacing.radiusExtraLarge),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: AppSpacing.responsiveAll(context, AppSpacing.standard),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
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
                  'Powered by Didit',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(context, AppTypography.base),
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(height: AppSpacing.extraSmall.responsive(context)),
                Text(
                  'Your data is encrypted and handled securely. Didit uses AI to verify identity documents and liveness in seconds.',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.extraSmall,
                    ),
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


