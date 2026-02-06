import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../legal/terms_of_service_screen.dart';
import '../legal/privacy_policy_screen.dart';
import 'package:rooverse/services/referral_service.dart';
import 'package:rooverse/services/supabase_service.dart';

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

  // Password strength checks
  bool get _hasMinLength => _passwordController.text.length >= 8;
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
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _referralFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _signupError = null;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
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

    // Validate email
    if (email.isEmpty) {
      setState(() {
        _emailError = 'Please enter an email';
      });
      hasError = true;
    } else if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      // Standard email validation regex that matches most valid email formats
      // This regex ensures:
      // - Local part: letters, numbers, and common symbols
      // - @ symbol
      // - Domain: letters, numbers, dots, hyphens
      // - TLD: at least 2 letters
      // This catches invalid formats while allowing valid emails like user.name+tag@gmail.com
      setState(() {
        _emailError = 'Please enter a valid email address';
      });
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
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(email, password, username);

    if (!mounted) return;

    if (success) {
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
    } else {
      setState(() {
        _signupError = authProvider.error ?? 'Signup failed';
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: scheme.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Join the Human Network',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: scheme.onBackground,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
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
                    TextSpan(text: ' and start earning RooCoin.'),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Form
              _buildInputField(
                context,
                label: 'Username',
                icon: Icons.person_outline,
                placeholder: 'Enter your username',
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                errorText: _usernameError,
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
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
                const SizedBox(height: 12),
                _buildPasswordRequirements(context),
              ],

              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              _buildInputField(
                context,
                label: 'Referral Code (Optional)',
                icon: Icons.card_giftcard_outlined,
                placeholder: 'Enter referral code',
                controller: _referralController,
                focusNode: _referralFocusNode,
                isReferral: true,
              ),

              const SizedBox(height: 20),

              // Policy checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11,
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _signupError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Signup button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: scheme.outline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Or continue with',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: scheme.onBackground.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: scheme.outline)),
                ],
              ),

              const SizedBox(height: 24),

              // Social buttons
              Row(
                children: [
                  Expanded(
                    child: _buildSocialButton(
                      context,
                      label: 'Apple',
                      icon: Icons.apple,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSocialButton(
                      context,
                      label: 'Google',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onBackground.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onLogin,
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          _buildRequirementRow('At least 8 characters', _hasMinLength),
          _buildRequirementRow('One uppercase letter (A-Z)', _hasUppercase),
          _buildRequirementRow('One lowercase letter (a-z)', _hasLowercase),
          _buildRequirementRow('One number (0-9)', _hasNumber),
          _buildRequirementRow(
            'One special character (!@#\$%^&*)',
            _hasSpecialChar,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onBackground.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() {});
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
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
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  icon,
                  size: 22,
                  color: hasError
                      ? Colors.red
                      : (focusNode?.hasFocus ?? false)
                      ? AppColors.primary
                      : scheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: isPassword ? obscure : false,
                    keyboardType: keyboardType,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
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
                if (isPassword)
                  IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 22,
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
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  errorText,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
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
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outline.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: scheme.onSurface.withOpacity(0.8)),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
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
}
