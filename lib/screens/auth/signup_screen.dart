import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rooverse/config/app_colors.dart';
import 'package:rooverse/config/app_spacing.dart';
import 'package:rooverse/config/app_typography.dart';
import 'package:rooverse/providers/auth_provider.dart';
import 'package:rooverse/providers/platform_config_provider.dart';
import 'package:rooverse/utils/responsive_extensions.dart';
import 'package:rooverse/screens/legal/terms_of_service_screen.dart';
import 'package:rooverse/screens/legal/privacy_policy_screen.dart';
import 'package:rooverse/utils/validators.dart';
import 'package:rooverse/services/referral_service.dart';
import 'package:rooverse/services/supabase_service.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class SignupScreen extends StatefulWidget {
  final VoidCallback onSignup;
  final VoidCallback onLogin;

  const SignupScreen({
    super.key,
    required this.onSignup,
    required this.onLogin,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _acceptedPolicy = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _referralFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _signupError;
  bool _isCheckingUsername = false;
  Timer? _debounceTimer;

  int get _minPasswordLength =>
      (context.read<PlatformConfigProvider>()).config.minPasswordLength;

  // Password strength checks
  bool get _hasMinLength => _passwordController.text.length >= _minPasswordLength;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  bool get _isPasswordStrong =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _usernameController.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    final username = _usernameController.text.trim();

    // Clear error immediately if empty or too short to be valid
    if (username.isEmpty || username.length < 3) {
      if (_usernameError != null) {
        setState(() => _usernameError = null);
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(username);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (!mounted) return;

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final isAvailable = await context
          .read<AuthProvider>()
          .isUsernameAvailable(username);

      if (!mounted) return;

      setState(() {
        _isCheckingUsername = false;
        if (!isAvailable) {
          _usernameError = 'This username is already taken';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingUsername = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _emailController.dispose();
    _debounceTimer?.cancel();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _referralFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final platformConfig = context.read<PlatformConfigProvider>().config;
    if (!platformConfig.allowNewSignups) {
      setState(() {
        _signupError = 'New sign-ups are currently disabled. Please try again later.';
      });
      return;
    }

    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _signupError = null;
    });

    final username = _usernameController.text.trim();
    final email = Validators.normalizeEmail(_emailController.text);
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    bool hasError = false;

    // Validate username
    if (username.isEmpty) {
      setState(() {
        _usernameError = 'Please enter a username';
      });
      hasError = true;
    } else if (username.length < 3) {
      setState(() {
        _usernameError = 'Username must be at least 3 characters';
      });
      hasError = true;
    } else if (username.length > 32) {
      setState(() {
        _usernameError = 'Username must be 32 characters or less';
      });
      hasError = true;
    }

    // Normalize and validate email
    _emailError = Validators.validateEmail(email);
    if (_emailError != null) {
      hasError = true;
    }

    // Validate password strength
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Please enter a password';
      });
      hasError = true;
    } else if (!_isPasswordStrong) {
      setState(() {
        _passwordError = 'Password does not meet all requirements';
      });
      hasError = true;
    }

    // Validate confirm password
    if (confirmPassword.isEmpty) {
      setState(() {
        _confirmPasswordError = 'Please confirm your password';
      });
      hasError = true;
    } else if (password != confirmPassword) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
      hasError = true;
    }

    // Validate policy acceptance
    if (!_acceptedPolicy) {
      setState(() {
        _signupError =
            'You must accept the Terms of Service and Privacy Policy';
      });
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isLoading = true);

    // Try Supabase signup
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signUp(email, password, username);

      if (!mounted) return;

      // Apply referral code if provided
      final referralCode = _referralController.text.trim();
      if (referralCode.isNotEmpty) {
        try {
          final userId = SupabaseService().client.auth.currentUser?.id;
          if (userId != null) {
            final referralService = ReferralService();
            await referralService.applyReferralCode(userId, referralCode);
          }
        } catch (e) {
          debugPrint('Error applying referral code: $e');
        }
      }

      // Proceed to verification screen
      widget.onSignup();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signupError = context.read<AuthProvider>().error ?? 'Signup failed';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignup() async {
    if (_isLoading) return;

    setState(() {
      _signupError = null;
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final launched = await authProvider.signInWithGoogle();

      if (!mounted) return;

      if (!launched) {
        setState(() {
          _signupError = authProvider.error ?? 'Unable to start Google sign-in';
          _isLoading = false;
        });
        return;
      }

      // OAuth completes asynchronously after the app callback/auth state update.
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signupError = context.read<AuthProvider>().error ?? 'Google signup failed';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.double_.responsive(context),
          ),
          child: Column(
            children: [
              SizedBox(height: 48.responsive(context, min: 36, max: 56)),

              // Header
              Container(
                width: 64.responsive(context, min: 56, max: 72),
                height: 64.responsive(context, min: 56, max: 72),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: AppSpacing.responsiveRadius(context, 32),
                  border: Border.all(color: scheme.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8.responsive(context),
                      offset: Offset(0, 4.responsive(context)),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: AppTypography.responsiveIconSize(context, 32),
                  color: AppColors.primary,
                ),
              ),

              SizedBox(height: AppSpacing.largePlus.responsive(context)),

              Text('Join the Human Network'.tr(context),
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    AppTypography.largeHeading,
                  ),
                  fontWeight: FontWeight.bold,
                  color: scheme.onBackground,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppSpacing.mediumSmall.responsive(context)),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.base,
                    ),
                    color: scheme.onBackground.withOpacity(0.7),
                  ),
                  children: const [
                    TextSpan(text: 'Secure your identity on '),
                    TextSpan(
                      text: 'ROOVERSE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' and start earning Roobyte.'),
                  ],
                ),
              ),

              SizedBox(height: 40.responsive(context, min: 32, max: 48)),

              // Form
              _buildInputField(
                context,
                label: 'Username',
                icon: Icons.person_outline,
                placeholder: 'Enter your username',
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                errorText: _usernameError,
                suffix: _buildUsernameSuffix(),
              ),
              SizedBox(height: AppSpacing.extraLarge.responsive(context)),
              _buildInputField(
                context,
                label: 'Email Address',
                icon: Icons.email_outlined,
                placeholder: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
                focusNode: _emailFocusNode,
                errorText: _emailError,
              ),
              SizedBox(height: AppSpacing.extraLarge.responsive(context)),
              _buildInputField(
                context,
                label: 'Password',
                icon: Icons.lock_outline,
                placeholder: 'Enter your password',
                isPassword: true,
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                errorText: _passwordError,
              ),

              // Password requirements
              if (_passwordController.text.isNotEmpty) ...[
                SizedBox(height: AppSpacing.standard.responsive(context)),
                _buildPasswordRequirements(context),
              ],

              SizedBox(height: AppSpacing.extraLarge.responsive(context)),
              _buildInputField(
                context,
                label: 'Confirm Password',
                icon: Icons.lock_outline,
                placeholder: 'Re-enter your password',
                isPassword: true,
                isConfirmPassword: true,
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                errorText: _confirmPasswordError,
              ),
              SizedBox(height: AppSpacing.extraLarge.responsive(context)),
              _buildInputField(
                context,
                label: 'Referral Code (Optional)',
                icon: Icons.card_giftcard_outlined,
                placeholder: 'Enter referral code',
                controller: _referralController,
                focusNode: _referralFocusNode,
                isReferral: true,
              ),

              SizedBox(height: AppSpacing.extraLarge.responsive(context)),

              // Policy checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24.responsive(context, min: 20, max: 28),
                    height: 24.responsive(context, min: 20, max: 28),
                    child: Checkbox(
                      value: _acceptedPolicy,
                      onChanged: (value) {
                        setState(() {
                          _acceptedPolicy = value ?? false;
                        });
                      },
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary;
                        }
                        return scheme.surface;
                      }),
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.standard.responsive(context)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: AppTypography.responsiveFontSize(
                            context,
                            AppTypography.tiny,
                          ),
                          color: scheme.onSurface.withOpacity(0.7),
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text: 'I verify that I am human and agree to the ',
                          ),
                          TextSpan(
                            text: 'Terms of Service',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TermsOfServiceScreen(),
                                  ),
                                );
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PrivacyPolicyScreen(),
                                  ),
                                );
                              },
                          ),
                          const TextSpan(text: ' (Strict No-AI Rule).'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (_signupError != null) ...[
                SizedBox(height: AppSpacing.largePlus.responsive(context)),
                Container(
                  padding: AppSpacing.responsiveAll(
                    context,
                    AppSpacing.standard,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: AppSpacing.responsiveRadius(
                      context,
                      AppSpacing.radiusSmall,
                    ),
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
                        width: AppSpacing.mediumSmall.responsive(context),
                      ),
                      Expanded(
                        child: Text(
                          _signupError!,
                          style: TextStyle(
                            color: Colors.red,
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
              ],

              SizedBox(height: AppSpacing.triple.responsive(context)),

              // Signup button
              SizedBox(
                width: double.infinity,
                height: 56.responsive(context, min: 48, max: 64),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.responsiveRadius(context, 28),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
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
                      : Text('Create Account'.tr(context),
                          style: TextStyle(
                            fontSize: AppTypography.responsiveFontSize(
                              context,
                              AppTypography.smallHeading,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              SizedBox(height: AppSpacing.triple.responsive(context)),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: scheme.outline)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.largePlus.responsive(context),
                    ),
                    child: Text('Or continue with'.tr(context),
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          AppTypography.extraSmall,
                        ),
                        fontWeight: FontWeight.bold,
                        color: scheme.onBackground.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: scheme.outline)),
                ],
              ),

              SizedBox(height: AppSpacing.triple.responsive(context)),

              // Social buttons
              Row(
                children: [
                  // Apple login/signup temporarily disabled.
                  // Expanded(
                  //   child: _buildSocialButton(
                  //     context,
                  //     label: 'Apple',
                  //     icon: Icons.apple,
                  //     onPressed: () {},
                  //   ),
                  // ),
                  // SizedBox(width: AppSpacing.standard.responsive(context)),
                  Expanded(
                    child: _buildSocialButton(
                      context,
                      label: 'Google',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: _isLoading ? null : _handleGoogleSignup,
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.triple.responsive(context)),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? '.tr(context),
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.base,
                      ),
                      color: scheme.onBackground.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onLogin,
                    child: Text('Log In'.tr(context),
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          AppTypography.base,
                        ),
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.triple.responsive(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: AppSpacing.responsiveAll(context, AppSpacing.standard),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppSpacing.responsiveRadius(
          context,
          AppSpacing.radiusSmall,
        ),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Password Requirements'.tr(context),
            style: TextStyle(
              fontSize: AppTypography.responsiveFontSize(
                context,
                AppTypography.extraSmall,
              ),
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withOpacity(0.8),
            ),
          ),
          SizedBox(height: AppSpacing.mediumSmall.responsive(context)),
          _buildRequirementRow(context, 'At least 8 characters', _hasMinLength),
          _buildRequirementRow(
            context,
            'One uppercase letter (A-Z)',
            _hasUppercase,
          ),
          _buildRequirementRow(
            context,
            'One lowercase letter (a-z)',
            _hasLowercase,
          ),
          _buildRequirementRow(context, 'One number (0-9)', _hasNumber),
          _buildRequirementRow(
            context,
            'One special character (!@#\$%^&*)',
            _hasSpecialChar,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(BuildContext context, String text, bool isMet) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.extraSmall.responsive(context) / 2,
      ),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: AppTypography.responsiveIconSize(context, 16),
            color: isMet ? Colors.green : Colors.grey,
          ),
          SizedBox(width: AppSpacing.mediumSmall.responsive(context)),
          Text(
            text,
            style: TextStyle(
              fontSize: AppTypography.responsiveFontSize(
                context,
                AppTypography.extraSmall,
              ),
              color: isMet ? Colors.green : Colors.grey,
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String placeholder,
    bool isPassword = false,
    bool isConfirmPassword = false,
    bool isReferral = false,
    TextInputType? keyboardType,
    TextEditingController? controller,
    FocusNode? focusNode,
    String? errorText,
    Widget? suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = errorText != null;
    final obscure = isConfirmPassword
        ? _obscureConfirmPassword
        : _obscurePassword;

    // Force uppercase for referral code as they are stored that way
    final textCapitalization = isReferral
        ? TextCapitalization.characters
        : TextCapitalization.none;

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
        Focus(
          onFocusChange: (hasFocus) {
            setState(() {});
          },
          child: Container(
            height: 56.responsive(context, min: 48, max: 64),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: AppSpacing.responsiveRadius(
                context,
                AppSpacing.radiusMedium,
              ),
              border: Border.all(
                color: hasError
                    ? Colors.red
                    : (focusNode?.hasFocus ?? false)
                    ? AppColors.primary
                    : scheme.outline.withOpacity(0.3),
                width: hasError
                    ? 2
                    : (focusNode?.hasFocus ?? false)
                    ? 2
                    : 1.5,
              ),
              boxShadow: [
                if (focusNode?.hasFocus ?? false)
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 8.responsive(context),
                    offset: Offset(0, 2.responsive(context)),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4.responsive(context),
                    offset: Offset(0, 2.responsive(context)),
                  ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(width: AppSpacing.largePlus.responsive(context)),
                Icon(
                  icon,
                  size: AppTypography.responsiveIconSize(context, 22),
                  color: hasError
                      ? Colors.red
                      : (focusNode?.hasFocus ?? false)
                      ? AppColors.primary
                      : scheme.onSurface.withOpacity(0.5),
                ),
                SizedBox(width: AppSpacing.medium.responsive(context)),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: isPassword ? obscure : false,
                    keyboardType: keyboardType,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.base,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withOpacity(0.4),
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textCapitalization: textCapitalization,
                  ),
                ),
                if (suffix != null) suffix,
                if (isPassword)
                  IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: AppTypography.responsiveIconSize(context, 22),
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                    onPressed: () {
                      setState(() {
                        if (isConfirmPassword) {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        } else {
                          _obscurePassword = !_obscurePassword;
                        }
                      });
                    },
                  ),
                SizedBox(width: AppSpacing.standard.responsive(context)),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: AppSpacing.mediumSmall.responsive(context)),
          Padding(
            padding: EdgeInsets.only(
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
                  errorText,
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
          ),
        ],
      ],
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppSpacing.responsiveRadius(
          context,
          AppSpacing.radiusMedium,
        ),
        child: Container(
          height: 54.responsive(context, min: 46, max: 62),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppSpacing.responsiveRadius(
              context,
              AppSpacing.radiusMedium,
            ),
            border: Border.all(
              color: scheme.outline.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4.responsive(context),
                offset: Offset(0, 2.responsive(context)),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppTypography.responsiveIconSize(context, 24),
                color: scheme.onSurface.withOpacity(0.8),
              ),
              SizedBox(width: AppSpacing.small.responsive(context)),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    AppTypography.base,
                  ),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildUsernameSuffix() {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length < 3) return null;

    if (_isCheckingUsername) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primary.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    if (_usernameError == null) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.check_circle, color: Colors.green, size: 20),
      );
    }

    return const Padding(
      padding: EdgeInsets.only(right: 12),
      child: Icon(Icons.error, color: Colors.red, size: 20),
    );
  }
}
