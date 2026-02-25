import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_extensions.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class VerificationScreen extends StatefulWidget {
  final VoidCallback onVerify;
  final VoidCallback? onBack;
  final VoidCallback? onChangeEmail;

  const VerificationScreen({
    super.key,
    required this.onVerify,
    this.onBack,
    this.onChangeEmail,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    _tickCooldown();
  }

  void _tickCooldown() {
    if (_resendCooldown > 0 && mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _resendCooldown--);
          _tickCooldown();
        }
      });
    }
  }

  String _getOtpCode() {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _handleVerify() async {
    final code = _getOtpCode();
    if (code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.verifyEmail(code);

      if (!mounted) return;

      // Poll for profile creation (database trigger might be slow)
      bool profileLoaded = false;
      int attempts = 0;

      while (!profileLoaded && attempts < 5) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await authProvider.reloadCurrentUser();
        if (authProvider.currentUser != null) {
          profileLoaded = true;
        }
        attempts++;
      }

      if (!mounted) return;
      widget.onVerify();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.read<AuthProvider>().error ?? 'Verification failed';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendConfirmation();

    if (!mounted) return;

    setState(() => _isResending = false);

    if (success) {
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification code resent!'.tr(context))),
      );
    } else {
      setState(() => _error = authProvider.error ?? 'Failed to resend code');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final email = authProvider.pendingEmail ?? 'your email';

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Gradient background blur
            Positioned(
              top: 0,
              left: MediaQuery.of(context).size.width / 2 -
                  200.responsive(context, min: 160, max: 240),
              child: Container(
                width: 400.responsive(context, min: 320, max: 480),
                height: 400.responsive(context, min: 320, max: 480),
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

            // Main content
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.double_.responsive(context),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppSpacing.double_.responsive(context),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed:
                              widget.onBack ??
                              () => Navigator.maybePop(context),
                          icon: Icon(
                            Icons.arrow_back,
                            color: scheme.onBackground,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.surface.withOpacity(0.8),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.standard.responsive(context),
                            vertical: AppSpacing.small.responsive(context),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: AppSpacing.responsiveRadius(
                                context, AppSpacing.radiusMedium),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.token,
                                size: AppTypography.responsiveIconSize(
                                    context, 16),
                                color: AppColors.primary,
                              ),
                              SizedBox(
                                  width:
                                      AppSpacing.extraSmall.responsive(context)),
                              Text('EARN ROO'.tr(context),
                                style: TextStyle(
                                  fontSize: AppTypography.responsiveFontSize(
                                      context, 10),
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 40.responsive(context, min: 32, max: 48)),
                      ],
                    ),
                  ),

                  SizedBox(height: 48.responsive(context, min: 36, max: 56)),

                  // Animated mail icon
                  Container(
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
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 40.responsive(context),
                          offset: Offset(0, 10.responsive(context)),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: 80.responsive(context, min: 68, max: 92),
                            height: 80.responsive(context, min: 68, max: 92),
                            decoration: BoxDecoration(
                              color: scheme.surface.withOpacity(0.25),
                              borderRadius:
                                  AppSpacing.responsiveRadius(context, 24),
                            ),
                            child: Icon(
                              Icons.mail,
                              size: AppTypography.responsiveIconSize(context, 40),
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        Positioned(
                          top: -4.responsive(context),
                          right: -4.responsive(context),
                          child: Container(
                            width: 32.responsive(context, min: 28, max: 36),
                            height: 32.responsive(context, min: 28, max: 36),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius:
                                  AppSpacing.responsiveRadius(context, 16),
                              border: Border.all(color: scheme.outline),
                            ),
                            child: Icon(
                              Icons.lock,
                              size: AppTypography.responsiveIconSize(context, 16),
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40.responsive(context, min: 32, max: 48)),

                  // Title
                  Text('Check your email'.tr(context),
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                          context, AppTypography.extraLargeHeading),
                      fontWeight: FontWeight.bold,
                      color: scheme.onBackground,
                      letterSpacing: -0.5,
                    ),
                  ),

                  SizedBox(height: AppSpacing.standard.responsive(context)),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(
                            context, AppTypography.base),
                        color: scheme.onBackground.withOpacity(0.7),
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: "We've sent a 6-digit code to\n"),
                        TextSpan(
                          text: email,
                          style: TextStyle(
                            color: scheme.onBackground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(
                          text: '. Enter it below to verify your humanity.',
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 48.responsive(context, min: 36, max: 56)),

                  // Code input fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48.responsive(context, min: 40, max: 56),
                        height: 56.responsive(context, min: 48, max: 64),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            fontSize: AppTypography.responsiveFontSize(
                                context, AppTypography.mediumHeading),
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: scheme.surface,
                            hintText: '-',
                            hintStyle: TextStyle(
                              color: scheme.onSurface.withOpacity(0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppSpacing.responsiveRadius(
                                  context, AppSpacing.radiusLarge),
                              borderSide: BorderSide(color: scheme.outline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppSpacing.responsiveRadius(
                                  context, AppSpacing.radiusLarge),
                              borderSide: BorderSide(color: scheme.outline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppSpacing.responsiveRadius(
                                  context, AppSpacing.radiusLarge),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),

                  SizedBox(height: 48.responsive(context, min: 36, max: 56)),

                  // Error message
                  if (_error != null) ...[
                    Container(
                      padding:
                          AppSpacing.responsiveAll(context, AppSpacing.standard),
                      margin: EdgeInsets.only(
                          bottom: AppSpacing.largePlus.responsive(context)),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: AppSpacing.responsiveRadius(
                            context, AppSpacing.radiusMedium),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: AppTypography.responsiveIconSize(context, 20),
                          ),
                          SizedBox(
                              width: AppSpacing.mediumSmall.responsive(context)),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: AppTypography.responsiveFontSize(
                                    context, AppTypography.small),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    height: 56.responsive(context, min: 48, max: 64),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.responsiveRadius(context, 28),
                        ),
                        elevation: 0,
                        shadowColor: AppColors.primary.withOpacity(0.3),
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.6),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24.responsive(context, min: 20, max: 28),
                              width: 24.responsive(context, min: 20, max: 28),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Verify Account'.tr(context),
                                  style: TextStyle(
                                    fontSize: AppTypography.responsiveFontSize(
                                        context, AppTypography.smallHeading),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(
                                    width: AppSpacing.mediumSmall
                                        .responsive(context)),
                                Icon(Icons.arrow_forward,
                                    size: AppTypography.responsiveIconSize(
                                        context, 20)),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: AppSpacing.double_.responsive(context)),

                  // Resend
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Didn't receive the code? ".tr(context),
                            style: TextStyle(
                              fontSize: AppTypography.responsiveFontSize(
                                  context, AppTypography.base),
                              color: scheme.onBackground.withOpacity(0.7),
                            ),
                          ),
                          if (_isResending)
                            SizedBox(
                              width: 16.responsive(context, min: 14, max: 18),
                              height: 16.responsive(context, min: 14, max: 18),
                              child:
                                  const CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            GestureDetector(
                              onTap: _resendCooldown > 0 ? null : _handleResend,
                              child: Text('Resend Email'.tr(context),
                                style: TextStyle(
                                  fontSize: AppTypography.responsiveFontSize(
                                      context, AppTypography.base),
                                  color: _resendCooldown > 0
                                      ? const Color(0xFF64748B)
                                      : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: _resendCooldown > 0
                                      ? TextDecoration.none
                                      : TextDecoration.underline,
                                ),
                              ),
                            ),
                          if (_resendCooldown > 0)
                            Text(' (${_resendCooldown ~/ 60}:${(_resendCooldown % 60).toString().padLeft(2, '.tr(context)0')})',
                              style: TextStyle(
                                fontSize: AppTypography.responsiveFontSize(
                                    context, AppTypography.base),
                                color: const Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.largePlus.responsive(context)),
                      TextButton(
                        onPressed:
                            widget.onChangeEmail ??
                            widget.onBack ??
                            () => Navigator.maybePop(context),
                        child: Text('CHANGE EMAIL ADDRESS'.tr(context),
                          style: TextStyle(
                            fontSize:
                                AppTypography.responsiveFontSize(context, 10),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 48.responsive(context, min: 36, max: 56)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
