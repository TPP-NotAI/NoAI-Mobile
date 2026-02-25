import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/validators.dart';
import '../../utils/responsive_extensions.dart';
import '../../utils/snackbar_utils.dart';
import 'phone_login_screen.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
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
    final secureStorage = SecureStorageService();
    final rememberMe = storage.getBool(_rememberMeKey) ?? false;
    if (rememberMe) {
      final savedEmail = await secureStorage.read(_savedEmailKey) ?? '';
      setState(() {
        _rememberMe = rememberMe;
        _emailController.text = savedEmail;
      });
    }
  }

  Future<void> _saveRememberMe() async {
    final storage = StorageService();
    final secureStorage = SecureStorageService();
    await storage.setBool(_rememberMeKey, _rememberMe);
    if (_rememberMe) {
      await secureStorage.write(_savedEmailKey, _emailController.text.trim());
    } else {
      await secureStorage.delete(_savedEmailKey);
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _loginError = null;
      _isRateLimited = false;
    });

    final email = Validators.normalizeEmail(_emailController.text);
    final password = _passwordController.text.trim();
    bool hasError = false;

    // Normalize and validate email
    _emailError = Validators.validateEmail(email);
    if (_emailError != null) {
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

    try {
      await authProvider.signIn(email, password);
      // Auth state listener will load the user profile
      widget.onLogin();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loginError = null;
      _isRateLimited = false;
    });

    final authProvider = context.read<AuthProvider>();

    try {
      final launched = await authProvider.signInWithGoogle();
      if (!mounted) return;

      if (!launched) {
        setState(() {
          _loginError = authProvider.error ?? 'Unable to start Google login';
          _isLoading = false;
        });
        return;
      }

      // OAuth returns to the app asynchronously via Supabase auth state.
      // Keep existing flows intact by not forcing navigation here.
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, e);
      setState(() => _isLoading = false);
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 80.responsive(context, min: 60, max: 100)),

              // Logo and title
              Container(
                width: 64.responsive(context, min: 56, max: 72),
                height: 64.responsive(context, min: 56, max: 72),
                decoration: BoxDecoration(
                  borderRadius: AppSpacing.responsiveRadius(
                    context,
                    AppSpacing.radiusExtraLarge,
                  ),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 12.responsive(context),
                      offset: Offset(0, 4.responsive(context)),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: AppTypography.responsiveIconSize(context, 32),
                  color: Colors.white,
                ),
              ),

              SizedBox(height: AppSpacing.largePlus.responsive(context)),

              Text('ROOVERSE'.tr(context),
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    AppTypography.largeHeading,
                  ),
                  fontWeight: FontWeight.bold,
                  color: scheme.onBackground,
                ),
              ),

              SizedBox(height: AppSpacing.mediumSmall.responsive(context)),

              Text('Authentic Human Connection'.tr(context),
                style: TextStyle(
                  color: scheme.onBackground.withOpacity(0.7),
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    AppTypography.small,
                  ),
                ),
              ),

              SizedBox(height: 48.responsive(context, min: 36, max: 56)),

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

              SizedBox(height: AppSpacing.extraLarge.responsive(context)),

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
                SizedBox(height: AppSpacing.standard.responsive(context)),
                _buildErrorMessage(scheme),
              ],

              SizedBox(height: AppSpacing.largePlus.responsive(context)),

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
                          width: 20.responsive(context, min: 18, max: 22),
                          height: 20.responsive(context, min: 18, max: 22),
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
                        SizedBox(
                          width: AppSpacing.mediumSmall.responsive(context),
                        ),
                        Text('Remember me'.tr(context),
                          style: TextStyle(
                            fontSize: AppTypography.responsiveFontSize(
                              context,
                              AppTypography.small,
                            ),
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
                    child: Text('Forgot Password?'.tr(context),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          AppTypography.small,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.mediumSmall.responsive(context)),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 56.responsive(context, min: 48, max: 64),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
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
                      : Text('Login'.tr(context),
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
                          AppTypography.small,
                        ),
                        color: scheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: scheme.outline)),
                ],
              ),

              SizedBox(height: AppSpacing.triple.responsive(context)),

              // Social login buttons
              Row(
                children: [
                  // Apple login temporarily disabled.
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
                      onPressed: _isLoading ? null : _handleGoogleLogin,
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.double_.responsive(context)),

              SizedBox(
                width: double.infinity,
                height: 56.responsive(context, min: 48, max: 64),
                child: OutlinedButton.icon(
                  onPressed: _openPhoneLogin,
                  icon: Icon(
                    Icons.phone_android,
                    color: scheme.onSurface,
                    size: AppTypography.responsiveIconSize(context, 24),
                  ),
                  label: Text('Login with phone number'.tr(context),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.base,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: scheme.surface,
                    side: BorderSide(color: scheme.outline.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.responsiveRadius(context, 28),
                    ),
                  ),
                ),
              ),

              SizedBox(height: AppSpacing.mediumSmall.responsive(context)),

              Text('Phone login also satisfies the human-verification step.'.tr(context),
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    AppTypography.tiny,
                  ),
                  color: scheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppSpacing.double_.responsive(context)),

              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New here? '.tr(context),
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.small,
                      ),
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
                    child: Text('Create an Account'.tr(context),
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          AppTypography.small,
                        ),
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

              SizedBox(height: AppSpacing.triple.responsive(context)),
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
      padding: AppSpacing.responsiveAll(context, AppSpacing.standard),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        borderRadius: AppSpacing.responsiveRadius(
          context,
          AppSpacing.radiusSmall,
        ),
        border: Border.all(color: errorColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: errorColor,
            size: AppTypography.responsiveIconSize(context, 20),
          ),
          SizedBox(width: AppSpacing.mediumSmall.responsive(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loginError!,
                  style: TextStyle(
                    color: errorColor,
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.small,
                    ),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isRateLimited) ...[
                  SizedBox(height: AppSpacing.extraSmall.responsive(context)),
                  Text('Please wait a few minutes before trying again.'.tr(context),
                    style: TextStyle(
                      color: errorColor.withOpacity(0.8),
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.tiny,
                      ),
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
                    obscureText: isPassword ? _obscurePassword : false,
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
                  ),
                ),
                if (isPassword)
                  IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: AppTypography.responsiveIconSize(context, 22),
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
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

  void _openPhoneLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneLoginScreen(onLogin: widget.onLogin),
      ),
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
}
