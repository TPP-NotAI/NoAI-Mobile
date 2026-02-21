import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';

import '../../config/app_colors.dart';
import '../../config/global_keys.dart';
import '../../providers/theme_provider.dart';
import '../../providers/wallet_provider.dart';
import 'user_search_sheet.dart';

class SendRooScreen extends StatefulWidget {
  final double currentBalance;
  final User? initialRecipient;

  const SendRooScreen({
    super.key,
    required this.currentBalance,
    this.initialRecipient,
  });

  @override
  State<SendRooScreen> createState() => _SendRooScreenState();
}

class _SendRooScreenState extends State<SendRooScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isProcessing = false;

  // Live search state
  List<User> _suggestions = [];
  bool _isSearchingSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialRecipient != null) {
      _recipientController.text = '@${widget.initialRecipient!.username}';
    }
    _recipientController.addListener(_onRecipientChanged);
  }

  @override
  void dispose() {
    _recipientController.removeListener(_onRecipientChanged);
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onRecipientChanged() {
    final text = _recipientController.text.trim();

    // Reset suggestions if too short or looks like an address
    if (text.length < 2 || text.startsWith('0x')) {
      if (_suggestions.isNotEmpty || _isSearchingSuggestions) {
        setState(() {
          _suggestions = [];
          _isSearchingSuggestions = false;
        });
      }
      return;
    }

    // Debounce search
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;

      setState(() => _isSearchingSuggestions = true);

      try {
        final query = text.startsWith('@') ? text.substring(1) : text;
        final results = await context.read<UserProvider>().searchUsers(query);
        final currentUserId = context.read<AuthProvider>().currentUser?.id;

        if (mounted) {
          setState(() {
            _suggestions = results
                .where((u) => u.id != currentUserId)
                .take(5)
                .toList();
            _isSearchingSuggestions = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearchingSuggestions = false);
        }
      }
    });
  }

  void _selectSuggestion(User user) {
    setState(() {
      _recipientController.text = '@${user.username}';
      _suggestions = [];
    });
    // Unfocus to hide keyboard and suggestions
    FocusScope.of(context).unfocus();
  }

  Future<Map<String, String?>?> _resolveUserAndAddress(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    // If it looks like an EVM address, return it
    final evmRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    if (evmRegex.hasMatch(cleanInput)) {
      return {'username': 'Recipient', 'address': cleanInput};
    }

    if (cleanInput.startsWith('PENDING_ACTIVATION_')) {
      return {'username': cleanInput, 'address': null};
    }

    // Otherwise assume it's a username
    try {
      final resolved = await context
          .read<UserProvider>()
          .resolveUsernameToAddress(cleanInput);

      final username = cleanInput.startsWith('@')
          ? cleanInput.substring(1)
          : cleanInput;

      return {'username': username, 'address': resolved['address']};
    } catch (e) {
      debugPrint('SendRooScreen: Error resolving: $e');
      return null;
    }
  }

  /// Platform withdrawal fee: 1% of the transfer amount.
  static const double _withdrawalFeeRate = 0.01;

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

    final fee = double.parse((amount * _withdrawalFeeRate).toStringAsFixed(6));
    final totalDeducted = amount + fee;

    if (totalDeducted > widget.currentBalance) {
      _showError(
        'Insufficient balance. You need ${totalDeducted.toStringAsFixed(2)} ROO '
        '(${amount.toStringAsFixed(2)} + ${fee.toStringAsFixed(2)} fee).',
      );
      return;
    }

    // Show fee confirmation dialog before proceeding
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FeeRow(label: 'Amount', value: '${amount.toStringAsFixed(2)} ROO'),
            _FeeRow(
              label: 'Platform fee (1%)',
              value: '${fee.toStringAsFixed(2)} ROO',
              isSubtle: true,
            ),
            const Divider(height: 16),
            _FeeRow(
              label: 'Total deducted',
              value: '${totalDeducted.toStringAsFixed(2)} ROO',
              bold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      setState(() => _isProcessing = false);
      _showError('User not logged in');
      return;
    }

    if (user.isVerificationPending) {
      setState(() => _isProcessing = false);
      _showError('Your verification is pending. You can send ROO once approved.');
      return;
    }

    if (!user.isVerified) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please complete identity verification to send ROO.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Verify',
            textColor: Colors.white,
            onPressed: () {
              if (context.mounted) {
                Navigator.pushNamed(context, '/verify');
              }
            },
          ),
        ),
      );
      return;
    }

    try {
      // 1. Resolve address
      final result = await _resolveUserAndAddress(recipient);
      if (result == null) {
        throw Exception('User not found');
      }

      final toAddress = result['address'];
      if (toAddress == null) {
        throw Exception(
          '${result['username']} hasn\'t activated their wallet yet',
        );
      }

      // Prevent self-sending
      if (toAddress.toLowerCase() ==
          walletProvider.wallet?.walletAddress.toLowerCase()) {
        throw Exception('You cannot send ROO to your own account');
      }

      final memo = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();

      // 2. Optimistic local update — deduct full amount including fee
      final localTxId = walletProvider.addOptimisticOutgoingTransaction(
        userId: user.id,
        amount: totalDeducted,
        txType: 'transfer',
        memo: memo,
        metadata: {
          'activityType': 'transfer',
          'inputRecipient': recipient,
          'withdrawal_fee': fee,
          'fee_rate': '1%',
        },
      );

      // 3. Close quickly and show "pending confirmation"
      if (mounted) {
        Navigator.pop(context);
      }
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            'Sent ${amount.toStringAsFixed(2)} ROO to $recipient (fee: ${fee.toStringAsFixed(2)} ROO). Confirming on-chain...',
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 4. Confirm in background and reconcile UI
      // The recipient receives `amount`; platform fee is deducted separately.
      unawaited(
        walletProvider
            .transferToExternal(
              userId: user.id,
              toAddress: toAddress,
              amount: amount,
              fee: fee,
              memo: memo,
              metadata: {
                'activityType': 'transfer',
                'inputRecipient': recipient,
                'withdrawal_fee': fee,
                'fee_rate': '1%',
              },
            )
            .then((success) async {
              if (success) {
                walletProvider.confirmOptimisticTransaction(localTxId);
                await walletProvider.refreshWallet(user.id).catchError(
                  (_) => null,
                );
                rootScaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Transfer confirmed: ${amount.toStringAsFixed(2)} ROO sent (${fee.toStringAsFixed(2)} ROO fee)',
                    ),
                    backgroundColor: Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final error =
                  walletProvider.error ?? 'Transfer failed. Balance restored.';
              walletProvider.rollbackOptimisticTransaction(
                localTxId,
                errorMessage: error,
              );
              rootScaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            })
            .catchError((e) {
              final error = e.toString().replaceAll('Exception: ', '');
              walletProvider.rollbackOptimisticTransaction(
                localTxId,
                errorMessage: error,
              );
              rootScaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
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
              onChanged: (_) {
                // Listener handles the logic, but we might want to trigger UI updates
              },
              decoration: InputDecoration(
                hintText: 'username or wallet address',
                hintStyle: TextStyle(color: textSecondaryColor),
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: textSecondaryColor,
                ),
                suffixIcon: _isSearchingSuggestions
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        width: 24,
                        height: 24,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(Icons.search, color: textSecondaryColor),
                        onPressed: () async {
                          final selectedUser = await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const UserSearchSheet(),
                          );

                          if (selectedUser != null) {
                            _selectSuggestion(selectedUser);
                          }
                        },
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

            // Suggestions List
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: borderColor.withOpacity(0.5)),
                  itemBuilder: (context, index) {
                    final user = _suggestions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundImage: user.avatar != null
                            ? NetworkImage(user.avatar!)
                            : null,
                        child: user.avatar == null
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      title: Text(
                        user.displayName,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _selectSuggestion(user),
                    );
                  },
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

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSubtle;
  final bool bold;

  const _FeeRow({
    required this.label,
    required this.value,
    this.isSubtle = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSubtle
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
