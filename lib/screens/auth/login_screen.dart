import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onRecover;

  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onSignup,
    required this.onRecover,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _emailError;
  String? _passwordError;
  String? _loginError;
  bool _isRateLimited = false;

  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
    // Clear error when user types
    _emailController.addListener(_clearLoginError);
    _passwordController.addListener(_clearLoginError);
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearLoginError);
    _passwordController.removeListener(_clearLoginError);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _clearLoginError() {
    if (_loginError != null) {
      setState(() {
        _loginError = null;
        _isRateLimited = false;
      });
    }
  }

  Future<void> _loadRememberMe() async {
    final storage = StorageService();
    final rememberMe = storage.getBool(_rememberMeKey) ?? false;
    if (rememberMe) {
      final savedEmail = storage.getString(_savedEmailKey) ?? '';
      setState(() {
        _rememberMe = rememberMe;
        _emailController.text = savedEmail;
      });
    }
  }

  Future<void> _saveRememberMe() async {
    final storage = StorageService();
    await storage.setBool(_rememberMeKey, _rememberMe);
    if (_rememberMe) {
      await storage.setString(_savedEmailKey, _emailController.text.trim());
    } else {
      await storage.remove(_savedEmailKey);
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _loginError = null;
      _isRateLimited = false;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    bool hasError = false;

    // Validate email
    if (email.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
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

    // Validate password
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Password is required';
      });
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isLoading = true);

    // Save remember me preference before login
    await _saveRememberMe();

    // Try Supabase auth
    final authProvider = context.read<AuthProvider>();
    if (!mounted) return;
    final success = await authProvider.signIn(email, password);

    if (!mounted) return;

    if (success) {
      // Auth state listener will load the user profile
      widget.onLogin();
    } else {
      final errorMsg = authProvider.error ?? 'Invalid email or password';
      final isRateLimited =
          errorMsg.toLowerCase().contains('too many') ||
          errorMsg.toLowerCase().contains('rate limit') ||
          errorMsg.toLowerCase().contains('try again later');
      setState(() {
        _loginError = errorMsg;
        _isRateLimited = isRateLimited;
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),

              // Logo and title
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 32,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'NOAI',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: scheme.onBackground,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Authentic Human Connection',
                style: TextStyle(
                  color: scheme.onBackground.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 48),

              // Login form
              _buildInputField(
                context,
                icon: Icons.email_outlined,
                label: 'Email',
                placeholder: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
                focusNode: _emailFocusNode,
                errorText: _emailError,
              ),

              const SizedBox(height: 20),

              _buildInputField(
                context,
                icon: Icons.lock_outline,
                label: 'Password',
                placeholder: 'Enter your password',
                isPassword: true,
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                errorText: _passwordError,
              ),

              if (_loginError != null) ...[
                const SizedBox(height: 12),
                _buildErrorMessage(scheme),
              ],

              const SizedBox(height: 16),

              // Remember me & Forgot password row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Remember me checkbox
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _rememberMe = !_rememberMe;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            fillColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.primary;
                              }
                              return scheme.surface;
                            }),
                            checkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: BorderSide(
                              color: scheme.outline.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurface.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Forgot password
                  TextButton(
                    onPressed: widget.onRecover,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
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
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: scheme.outline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Or continue with',
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: scheme.outline)),
                ],
              ),

              const SizedBox(height: 32),

              // Social login buttons
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

              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New here? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onSignup,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Create an Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: scheme.onBackground,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                        decorationThickness: 2,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(ColorScheme scheme) {
    final isRateLimited = _isRateLimited;
    final errorColor = isRateLimited ? Colors.orange : Colors.red;
    final icon = isRateLimited ? Icons.timer_outlined : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: errorColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: errorColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loginError!,
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isRateLimited) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Please wait a few minutes before trying again.',
                    style: TextStyle(
                      color: errorColor.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String placeholder,
    bool isPassword = false,
    TextInputType? keyboardType,
    TextEditingController? controller,
    FocusNode? focusNode,
    String? errorText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = errorText != null;

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
                    obscureText: isPassword ? _obscurePassword : false,
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
                  ),
                ),
                if (isPassword)
                  IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 22,
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
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
