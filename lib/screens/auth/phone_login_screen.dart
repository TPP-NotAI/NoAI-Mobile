import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../constants/country_calling_codes.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_extensions.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class PhoneLoginScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const PhoneLoginScreen({super.key, required this.onLogin});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _codeSent = false;
  String? _error;
  int _resendCooldown = 0;
  String _selectedCountryCode = '+1';

  final List<Map<String, String>> _countryCodes = kCountryCallingCodes;

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _fullPhoneNumber =>
      '$_selectedCountryCode${_phoneController.text.trim()}';

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
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

  String _getOtpCode() => _otpControllers.map((c) => c.text).join();

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return;
    }

    if (phone.length < 8) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendLoginOtp(_fullPhoneNumber);

    if (!mounted) return;

    if (success) {
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
      _startResendCooldown();
    } else {
      setState(() {
        _error = authProvider.error ?? 'Failed to send login code';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _getOtpCode();
    if (code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyLoginOtp(
      _fullPhoneNumber,
      code,
    );

    if (!mounted) return;

    if (success) {
      await authProvider.updateVerificationStatus('phone');
      if (!mounted) return;
      widget.onLogin();
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _error = authProvider.error ?? 'Invalid verification code';
        _isLoading = false;
      });
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;
    await _sendCode();
  }

  void _resetOtpInputs() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    for (var node in _otpFocusNodes) {
      node.unfocus();
    }
  }

  void _changePhoneNumber() {
    setState(() {
      _codeSent = false;
      _error = null;
    });
    _resetOtpInputs();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80.responsive(context),
              right: -80.responsive(context),
              child: Container(
                width: 260.responsive(context, min: 220, max: 300),
                height: 260.responsive(context, min: 220, max: 300),
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
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: scheme.onSurface),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.double_.responsive(context)),

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
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 30.responsive(context),
                          offset: Offset(0, 10.responsive(context)),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.phone_android,
                      size: AppTypography.responsiveIconSize(context, 48),
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: AppSpacing.double_.responsive(context)),

                  Text('Login with Phone'.tr(context),
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                          context, AppTypography.largeHeading),
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),

                  SizedBox(height: AppSpacing.mediumSmall.responsive(context)),

                  Text('Enter your number to receive a one-time code. This also completes the human verification requirement.'.tr(context),
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                          context, AppTypography.base),
                      color: scheme.onSurface.withOpacity(0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: AppSpacing.triple.responsive(context)),

                  if (!_codeSent) _buildPhoneInput(scheme),
                  if (_codeSent) ...[
                    _buildOtpInput(scheme),
                    SizedBox(height: AppSpacing.largePlus.responsive(context)),
                  ],

                  if (_error != null) ...[
                    Container(
                      padding:
                          AppSpacing.responsiveAll(context, AppSpacing.standard),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: AppSpacing.responsiveRadius(
                            context, AppSpacing.radiusMedium),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red,
                              size:
                                  AppTypography.responsiveIconSize(context, 20)),
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
                    SizedBox(height: AppSpacing.largePlus.responsive(context)),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 56.responsive(context, min: 48, max: 64),
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _codeSent
                              ? _verifyCode
                              : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.responsiveRadius(context, 28),
                        ),
                        elevation: 0,
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.6),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24.responsive(context, min: 20, max: 28),
                              width: 24.responsive(context, min: 20, max: 28),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _codeSent ? 'Verify & Login' : 'Send Code',
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

                  if (_codeSent) ...[
                    SizedBox(height: AppSpacing.largePlus.responsive(context)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Didn't receive the code? ".tr(context),
                          style: TextStyle(
                            fontSize: AppTypography.responsiveFontSize(
                                context, AppTypography.base),
                            color: scheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        GestureDetector(
                          onTap: _resendCooldown > 0 ? null : _resendCode,
                          child: Text('Resend'.tr(context),
                            style: TextStyle(
                              fontSize: AppTypography.responsiveFontSize(
                                  context, AppTypography.base),
                              color: _resendCooldown > 0
                                  ? Colors.grey
                                  : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              decoration: _resendCooldown > 0
                                  ? TextDecoration.none
                                  : TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (_resendCooldown > 0)
                          Text(' (${_resendCooldown}s)'.tr(context),
                            style: TextStyle(
                              fontSize: AppTypography.responsiveFontSize(
                                  context, AppTypography.base),
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: AppSpacing.mediumSmall.responsive(context)),

                    TextButton(
                      onPressed: _changePhoneNumber,
                      child: Text('Change phone number'.tr(context),
                        style: TextStyle(
                          fontSize: AppTypography.responsiveFontSize(
                              context, AppTypography.extraSmall),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: AppSpacing.triple.responsive(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius:
            AppSpacing.responsiveRadius(context, AppSpacing.radiusLarge),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.standard.responsive(context),
            ),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: scheme.outline.withOpacity(0.3)),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                items: _countryCodes.map((country) {
                  return DropdownMenuItem(
                    value: country['code'],
                    child: Text('${country['code']} ${country['country']}',
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(
                            context, AppTypography.base),
                        color: scheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCountryCode = value);
                  }
                },
                dropdownColor: scheme.surface,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(
                    context, AppTypography.smallHeading),
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Phone number',
                hintStyle: TextStyle(
                  color: scheme.onSurface.withOpacity(0.4),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.largePlus.responsive(context),
                  vertical: AppSpacing.largePlus.responsive(context),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 48.responsive(context, min: 40, max: 56),
          height: 56.responsive(context, min: 48, max: 64),
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
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
              fillColor: scheme.surfaceContainerHighest,
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
                _otpFocusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _otpFocusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }
}
