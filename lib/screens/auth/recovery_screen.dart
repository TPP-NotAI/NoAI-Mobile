import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_extensions.dart';
import '../../utils/validators.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class RecoveryScreen extends StatefulWidget {
  final VoidCallback onBack;

  const RecoveryScreen({super.key, required this.onBack});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  String? _error;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _handleSendEmail() async {
    final normalizedEmail = Validators.normalizeEmail(_emailController.text);
    final emailError = Validators.validateEmail(normalizedEmail);
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(normalizedEmail);

    if (mounted) {
      if (success) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = authProvider.error ?? 'Failed to send recovery email';
          _isLoading = false;
        });
      }
    }
  }

  void _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyRecoveryOtp(otp);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (!success) {
        setState(() {
          _error = authProvider.error ?? 'Invalid verification code';
        });
      }
    }
  }

  void _handleResetPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updatePassword(password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (!success) {
        setState(() {
          _error = authProvider.error ?? 'Failed to reset password';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final currentStep = authProvider.recoveryStep;

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.double_.responsive(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: AppSpacing.largePlus.responsive(context),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        authProvider.resetRecoveryFlow();
                        widget.onBack();
                      },
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: scheme.onBackground,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.onBackground.withOpacity(0.08),
                      ),
                    ),
                    Text('RECOVERY'.tr(context),
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(context, 10),
                        fontWeight: FontWeight.bold,
                        color: scheme.onBackground.withOpacity(0.6),
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(width: 40.responsive(context, min: 32, max: 48)),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.double_.responsive(context)),

              // Progress indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressDot(0, currentStep, scheme),
                  SizedBox(width: AppSpacing.standard.responsive(context)),
                  _buildProgressDot(1, currentStep, scheme),
                  SizedBox(width: AppSpacing.standard.responsive(context)),
                  _buildProgressDot(2, currentStep, scheme),
                ],
              ),

              SizedBox(height: AppSpacing.triple.responsive(context)),

              // Step Content
              if (currentStep == RecoveryStep.email)
                _buildEmailStep(scheme, authProvider)
              else if (currentStep == RecoveryStep.otp)
                _buildOtpStep(scheme, authProvider)
              else if (currentStep == RecoveryStep.newPassword)
                _buildNewPasswordStep(scheme, authProvider)
              else if (currentStep == RecoveryStep.success)
                _buildSuccessStep(scheme, authProvider),

              SizedBox(height: 48.responsive(context, min: 36, max: 56)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(
    int index,
    RecoveryStep currentStep,
    ColorScheme scheme,
  ) {
    bool active = false;
    bool completed = false;

    int currentIdx = 0;
    if (currentStep == RecoveryStep.otp) currentIdx = 1;
    if (currentStep == RecoveryStep.newPassword) currentIdx = 2;
    if (currentStep == RecoveryStep.success) currentIdx = 3;

    active = currentIdx == index;
    completed = currentIdx > index;

    return Container(
      width: active
          ? 32.responsive(context, min: 28, max: 36)
          : 8.responsive(context, min: 6, max: 10),
      height: 8.responsive(context, min: 6, max: 10),
      decoration: BoxDecoration(
        color: active || completed ? AppColors.primary : scheme.outline,
        borderRadius: BorderRadius.circular(4),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8.responsive(context),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildEmailStep(ColorScheme scheme, AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleSection('Forgot Password?'),
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: AppTypography.responsiveFontSize(
                context,
                AppTypography.smallHeading,
              ),
              color: scheme.onBackground.withOpacity(0.7),
              height: 1.5,
            ),
            children: const [
              TextSpan(
                text:
                    'Enter the email associated with your ROOVERSE account. We\'ll send you a ',
              ),
              TextSpan(
                text: 'Roobyte-secured',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: ' verification code.'),
            ],
          ),
        ),
        SizedBox(height: 40.responsive(context, min: 32, max: 48)),
        _buildTextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          label: 'Email Address',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          scheme: scheme,
        ),
        if (_error != null) _buildErrorMessage(),
        SizedBox(height: AppSpacing.double_.responsive(context)),
        _buildButton(
          text: 'Send Code',
          onPressed: _handleSendEmail,
          isLoading: _isLoading,
        ),
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        Center(
          child: TextButton(
            onPressed: widget.onBack,
            child: Text('Remember your password? Log In'.tr(context),
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(
                  context,
                  AppTypography.base,
                ),
                fontWeight: FontWeight.bold,
                color: scheme.onBackground.withOpacity(0.7),
              ),
            ),
          ),
        ),
        SizedBox(height: 48.responsive(context, min: 36, max: 56)),
        _buildSecurityCard(scheme),
      ],
    );
  }

  Widget _buildOtpStep(ColorScheme scheme, AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleSection('Verify Code'),
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        Text('We\'ve sent a 6-digit verification code to ${authProvider.pendingEmail ?? '.tr(context)your email'}. Please enter it below to proceed.',
          style: TextStyle(
            fontSize: AppTypography.responsiveFontSize(
              context,
              AppTypography.smallHeading,
            ),
            color: scheme.onBackground.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        SizedBox(height: 40.responsive(context, min: 32, max: 48)),
        _buildTextField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          label: 'Verification Code',
          hint: 'Enter 6-digit code',
          icon: Icons.security,
          keyboardType: TextInputType.number,
          scheme: scheme,
        ),
        if (_error != null) _buildErrorMessage(),
        SizedBox(height: AppSpacing.double_.responsive(context)),
        _buildButton(
          text: 'Verify Code',
          onPressed: _handleVerifyOtp,
          isLoading: _isLoading,
        ),
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        Center(
          child: TextButton(
            onPressed: _handleSendEmail,
            child: Text('Resend Code'.tr(context),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.responsiveFontSize(
                  context,
                  AppTypography.base,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 48.responsive(context, min: 36, max: 56)),
        _buildSecurityCard(scheme),
      ],
    );
  }

  Widget _buildNewPasswordStep(ColorScheme scheme, AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleSection('New Password'),
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        Text('Verification successful! Create a strong new password for your account.'.tr(context),
          style: TextStyle(
            fontSize: AppTypography.responsiveFontSize(
              context,
              AppTypography.smallHeading,
            ),
            color: scheme.onBackground.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        SizedBox(height: 40.responsive(context, min: 32, max: 48)),
        _buildTextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          label: 'New Password',
          hint: 'Enter new password',
          icon: Icons.lock_outline,
          isPassword: true,
          obscureText: _obscurePassword,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          scheme: scheme,
        ),
        SizedBox(height: AppSpacing.extraLarge.responsive(context)),
        _buildTextField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode,
          label: 'Confirm Password',
          hint: 'Confirm your password',
          icon: Icons.lock_reset,
          isPassword: true,
          obscureText: _obscureConfirmPassword,
          onTogglePassword: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
          scheme: scheme,
        ),
        if (_error != null) _buildErrorMessage(),
        SizedBox(height: AppSpacing.triple.responsive(context)),
        _buildButton(
          text: 'Reset Password',
          onPressed: _handleResetPassword,
          isLoading: _isLoading,
        ),
        SizedBox(height: 48.responsive(context, min: 36, max: 56)),
        _buildSecurityCard(scheme),
      ],
    );
  }

  Widget _buildSecurityCard(ColorScheme scheme) {
    return Container(
      padding: AppSpacing.responsiveAll(context, AppSpacing.largePlus),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: AppSpacing.responsiveRadius(
          context,
          AppSpacing.radiusLarge,
        ),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 32.responsive(context, min: 28, max: 36),
            height: 32.responsive(context, min: 28, max: 36),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: AppSpacing.responsiveRadius(context, 16),
            ),
            child: Icon(
              Icons.shield,
              size: AppTypography.responsiveIconSize(context, 18),
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: AppSpacing.standard.responsive(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROOKEN PROTECTED'.tr(context),
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(context, 10),
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: AppSpacing.extraSmall.responsive(context)),
                Text('End-to-end encrypted credential reset.'.tr(context),
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(context, 10),
                    color: scheme.onBackground.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep(ColorScheme scheme, AuthProvider authProvider) {
    return Column(
      children: [
        SizedBox(height: 40.responsive(context, min: 32, max: 48)),
        Container(
          width: 80.responsive(context, min: 68, max: 92),
          height: 80.responsive(context, min: 68, max: 92),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: AppTypography.responsiveIconSize(context, 48),
            color: Colors.green,
          ),
        ),
        SizedBox(height: AppSpacing.double_.responsive(context)),
        Text('Password Reset!'.tr(context),
          style: TextStyle(
            fontSize: AppTypography.responsiveFontSize(
              context,
              AppTypography.mediumHeading,
            ),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        Text('Your password has been successfully reset. You can now use your new password to log in.'.tr(context),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTypography.responsiveFontSize(
              context,
              AppTypography.smallHeading,
            ),
            color: scheme.onBackground.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        SizedBox(height: 48.responsive(context, min: 36, max: 56)),
        _buildButton(
          text: 'Back to Login',
          onPressed: () {
            authProvider.resetRecoveryFlow();
            widget.onBack();
          },
          isLoading: false,
        ),
      ],
    );
  }

  Widget _buildTitleSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lock_reset,
              size: AppTypography.responsiveIconSize(context, 20),
              color: AppColors.primary,
            ),
            SizedBox(width: AppSpacing.mediumSmall.responsive(context)),
            Text('SECURE RECOVERY'.tr(context),
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(context, 10),
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.largePlus.responsive(context)),
        Text(
          title,
          style: TextStyle(
            fontSize: AppTypography.responsiveFontSize(
              context,
              AppTypography.extraLargeHeading,
            ),
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    required ColorScheme scheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.responsiveFontSize(
              context,
              AppTypography.base,
            ),
            fontWeight: FontWeight.w600,
            color: scheme.onBackground.withOpacity(0.9),
          ),
        ),
        SizedBox(height: AppSpacing.mediumSmall.responsive(context)),
        Container(
          height: 56.responsive(context, min: 48, max: 64),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppSpacing.responsiveRadius(
              context,
              AppSpacing.radiusMedium,
            ),
            border: Border.all(
              color: focusNode.hasFocus
                  ? AppColors.primary
                  : scheme.outline.withOpacity(0.3),
              width: focusNode.hasFocus ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: AppSpacing.largePlus.responsive(context)),
              Icon(
                icon,
                color: focusNode.hasFocus
                    ? AppColors.primary
                    : scheme.onSurface.withOpacity(0.5),
                size: AppTypography.responsiveIconSize(context, 22),
              ),
              SizedBox(width: AppSpacing.medium.responsive(context)),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.base,
                    ),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: scheme.onSurface.withOpacity(0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {
                    _error = null;
                  }),
                  onTap: () => setState(() {}),
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: AppTypography.responsiveIconSize(context, 20),
                    color: scheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: onTogglePassword,
                ),
              SizedBox(width: AppSpacing.standard.responsive(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.mediumSmall.responsive(context),
        left: AppSpacing.extraSmall.responsive(context),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: AppTypography.responsiveIconSize(context, 14),
            color: Colors.red,
          ),
          SizedBox(width: AppSpacing.extraSmall.responsive(context)),
          Text(
            _error!,
            style: TextStyle(
              color: Colors.red,
              fontSize: AppTypography.responsiveFontSize(
                context,
                AppTypography.small,
              ),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56.responsive(context, min: 48, max: 64),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.responsiveRadius(context, 28),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                height: 24.responsive(context, min: 20, max: 28),
                width: 24.responsive(context, min: 20, max: 28),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    AppTypography.smallHeading,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
