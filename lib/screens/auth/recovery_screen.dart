import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';

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
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter an email');
      return;
    }

    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(email);

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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                    Text(
                      'RECOVERY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: scheme.onBackground.withOpacity(0.6),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Progress indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressDot(0, currentStep, scheme),
                  const SizedBox(width: 12),
                  _buildProgressDot(1, currentStep, scheme),
                  const SizedBox(width: 12),
                  _buildProgressDot(2, currentStep, scheme),
                ],
              ),

              const SizedBox(height: 32),

              // Step Content
              if (currentStep == RecoveryStep.email)
                _buildEmailStep(scheme, authProvider)
              else if (currentStep == RecoveryStep.otp)
                _buildOtpStep(scheme, authProvider)
              else if (currentStep == RecoveryStep.newPassword)
                _buildNewPasswordStep(scheme, authProvider)
              else if (currentStep == RecoveryStep.success)
                _buildSuccessStep(scheme, authProvider),

              const SizedBox(height: 48),
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
      width: active ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active || completed ? AppColors.primary : scheme.outline,
        borderRadius: BorderRadius.circular(4),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
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
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: scheme.onBackground.withOpacity(0.7),
              height: 1.5,
            ),
            children: const [
              TextSpan(
                text:
                    'Enter the email associated with your NOAI account. We\'ll send you a ',
              ),
              TextSpan(
                text: 'RooCoin-secured',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: ' verification code.'),
            ],
          ),
        ),
        const SizedBox(height: 40),
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
        const SizedBox(height: 24),
        _buildButton(
          text: 'Send Code',
          onPressed: _handleSendEmail,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: widget.onBack,
            child: Text(
              'Remember your password? Log In',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: scheme.onBackground.withOpacity(0.7),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        _buildSecurityCard(scheme),
      ],
    );
  }

  Widget _buildOtpStep(ColorScheme scheme, AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleSection('Verify Code'),
        const SizedBox(height: 16),
        Text(
          'We\'ve sent a 6-digit verification code to ${authProvider.pendingEmail ?? 'your email'}. Please enter it below to proceed.',
          style: TextStyle(
            fontSize: 16,
            color: scheme.onBackground.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
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
        const SizedBox(height: 24),
        _buildButton(
          text: 'Verify Code',
          onPressed: _handleVerifyOtp,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _handleSendEmail,
            child: const Text(
              'Resend Code',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        _buildSecurityCard(scheme),
      ],
    );
  }

  Widget _buildNewPasswordStep(ColorScheme scheme, AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleSection('New Password'),
        const SizedBox(height: 16),
        Text(
          'Verification successful! Create a strong new password for your account.',
          style: TextStyle(
            fontSize: 16,
            color: scheme.onBackground.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
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
        const SizedBox(height: 20),
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
        const SizedBox(height: 32),
        _buildButton(
          text: 'Reset Password',
          onPressed: _handleResetPassword,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 48),
        _buildSecurityCard(scheme),
      ],
    );
  }

  Widget _buildSecurityCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROOCOIN PROTECTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'End-to-end encrypted credential reset.',
                  style: TextStyle(
                    fontSize: 10,
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
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, size: 48, color: Colors.green),
        ),
        const SizedBox(height: 24),
        const Text(
          'Password Reset!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Your password has been successfully reset. You can now use your new password to log in.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: scheme.onBackground.withOpacity(0.7),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
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
          children: const [
            Icon(Icons.lock_reset, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'SECURE RECOVERY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onBackground.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focusNode.hasFocus
                  ? AppColors.primary
                  : scheme.outline.withOpacity(0.3),
              width: focusNode.hasFocus ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                icon,
                color: focusNode.hasFocus
                    ? AppColors.primary
                    : scheme.onSurface.withOpacity(0.5),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: TextStyle(color: scheme.onSurface, fontSize: 15),
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
                    size: 20,
                    color: scheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: onTogglePassword,
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            _error!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
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
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
