import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';

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

  final List<Map<String, String>> _countryCodes = [
    {'code': '+1', 'country': 'US/CA'},
    {'code': '+44', 'country': 'UK'},
    {'code': '+61', 'country': 'AU'},
    {'code': '+91', 'country': 'IN'},
    {'code': '+49', 'country': 'DE'},
    {'code': '+33', 'country': 'FR'},
    {'code': '+81', 'country': 'JP'},
    {'code': '+86', 'country': 'CN'},
    {'code': '+55', 'country': 'BR'},
    {'code': '+52', 'country': 'MX'},
  ];

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
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
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

                  const SizedBox(height: 24),

                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.phone_android, size: 48, color: Colors.white),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Login with Phone',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Enter your number to receive a one-time code. This also completes the human verification requirement.',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface.withOpacity(0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  if (!_codeSent) _buildPhoneInput(scheme),
                  if (_codeSent) ...[
                    _buildOtpInput(scheme),
                    const SizedBox(height: 16),
                  ],

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
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
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 56,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _codeSent ? 'Verify & Login' : 'Send Code',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                  ),

                  if (_codeSent) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code? ",
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        GestureDetector(
                          onTap: _resendCooldown > 0 ? null : _resendCode,
                          child: Text(
                            'Resend',
                            style: TextStyle(
                              fontSize: 14,
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
                          Text(
                            ' (${_resendCooldown}s)',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: _changePhoneNumber,
                      child: const Text(
                        'Change phone number',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    child: Text(
                      '${country['code']} ${country['country']}',
                      style: TextStyle(
                        fontSize: 14,
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
                fontSize: 16,
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Phone number',
                hintStyle: TextStyle(
                  color: scheme.onSurface.withOpacity(0.4),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
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
          width: 48,
          height: 56,
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: TextStyle(
              fontSize: 24,
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
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
