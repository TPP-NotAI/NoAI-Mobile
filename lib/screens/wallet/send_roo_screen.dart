import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

import '../../config/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/supabase_service.dart';

class SendRooScreen extends StatefulWidget {
  final double currentBalance;

  const SendRooScreen({super.key, required this.currentBalance});

  @override
  State<SendRooScreen> createState() => _SendRooScreenState();
}

class _SendRooScreenState extends State<SendRooScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isProcessing = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<String?> _resolveAddress(String input) async {
    // If it looks like an ETH address, return it
    if (input.startsWith('0x') && input.length == 42) {
      return input;
    }

    // Otherwise assume it's a username
    try {
      final cleanUsername = input.startsWith('@') ? input.substring(1) : input;
      final response = await SupabaseService().client
          .from('profiles')
          .select('user_id')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (response == null) return null;
      final userId = response['user_id'] as String;

      final walletResponse = await SupabaseService().client
          .from('wallets')
          .select('wallet_address')
          .eq('user_id', userId)
          .maybeSingle();

      if (walletResponse == null) return null;
      return walletResponse['wallet_address'] as String;
    } catch (e) {
      debugPrint('Error resolving username: $e');
      return null;
    }
  }

  Future<void> _sendRoo() async {
    final recipient = _recipientController.text.trim();
    final amountText = _amountController.text.trim();

    if (recipient.isEmpty) {
      _showError('Please enter a recipient');
      return;
    }

    if (amountText.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (amount > widget.currentBalance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isProcessing = true);

    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      setState(() => _isProcessing = false);
      _showError('User not logged in');
      return;
    }

    try {
      // 1. Resolve address
      final toAddress = await _resolveAddress(recipient);
      if (toAddress == null) {
        throw Exception('Recipient not found or has no wallet');
      }

      // 2. Perform transfer
      await walletProvider.transferToExternal(
        userId: user.id,
        toAddress: toAddress,
        amount: amount,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Transaction Successful!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Sent ${amount.toStringAsFixed(2)} ROO to',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                recipient,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to wallet screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surfaceColor = isDarkMode
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final textPrimaryColor = isDarkMode
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondaryColor = isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final borderColor = isDarkMode
        ? AppColors.outlineDark
        : AppColors.outlineLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Send ROO',
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF8C00), width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.currentBalance.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          'ROO',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Recipient Field
            Text(
              'Recipient',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recipientController,
              style: TextStyle(color: textPrimaryColor),
              decoration: InputDecoration(
                hintText: 'username or wallet address',
                hintStyle: TextStyle(color: textSecondaryColor),
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: textSecondaryColor,
                ),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Amount Field
            Text(
              'Amount (ROO)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: TextStyle(color: textPrimaryColor),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: textSecondaryColor),
                prefixIcon: Icon(Icons.toll, color: textSecondaryColor),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),

            // Quick Amount Buttons
            const SizedBox(height: 16),
            Row(
              children: [
                _buildQuickAmountButton(
                  '10',
                  textPrimaryColor,
                  surfaceColor,
                  borderColor,
                ),
                const SizedBox(width: 8),
                _buildQuickAmountButton(
                  '50',
                  textPrimaryColor,
                  surfaceColor,
                  borderColor,
                ),
                const SizedBox(width: 8),
                _buildQuickAmountButton(
                  '100',
                  textPrimaryColor,
                  surfaceColor,
                  borderColor,
                ),
                const SizedBox(width: 8),
                _buildQuickAmountButton(
                  'Max',
                  textPrimaryColor,
                  surfaceColor,
                  borderColor,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Note Field (Optional)
            Text(
              'Note (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 100,
              style: TextStyle(color: textPrimaryColor),
              decoration: InputDecoration(
                hintText: 'Add a message...',
                hintStyle: TextStyle(color: textSecondaryColor),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _sendRoo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Send ROO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(
    String label,
    Color textColor,
    Color bgColor,
    Color borderColor,
  ) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          if (label == 'Max') {
            _amountController.text = widget.currentBalance.toStringAsFixed(2);
          } else {
            _amountController.text = label;
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
          backgroundColor: bgColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
