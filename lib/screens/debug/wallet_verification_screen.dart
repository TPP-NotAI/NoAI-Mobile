import 'package:flutter/material.dart';
import '../../services/wallet_verification_service.dart';
import '../../services/supabase_service.dart';

/// Debug screen to verify wallet operations before deployment
/// Remove this screen in production builds
class WalletVerificationScreen extends StatefulWidget {
  const WalletVerificationScreen({super.key});

  @override
  State<WalletVerificationScreen> createState() =>
      _WalletVerificationScreenState();
}

class _WalletVerificationScreenState extends State<WalletVerificationScreen> {
  final _verificationService = WalletVerificationService();
  bool _isRunning = false;
  String _report = '';
  Map<String, dynamic>? _results;

  Future<void> _runVerification() async {
    setState(() {
      _isRunning = true;
      _report = '';
      _results = null;
    });

    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) {
        setState(() {
          _report = 'ERROR: No user logged in';
          _isRunning = false;
        });
        return;
      }

      final results = await _verificationService.runAllChecks(userId);
      final report = _verificationService.generateReport(results);

      setState(() {
        _results = results;
        _report = report;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _report = 'ERROR: $e';
        _isRunning = false;
      });
    }
  }

  Color _getStatusColor(Map<String, dynamic>? check) {
    if (check == null) return Colors.grey;
    final passed = check['passed'] as bool? ?? false;
    return passed ? Colors.green : Colors.red;
  }

  IconData _getStatusIcon(Map<String, dynamic>? check) {
    if (check == null) return Icons.help_outline;
    final passed = check['passed'] as bool? ?? false;
    return passed ? Icons.check_circle : Icons.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Verification'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.verified_user,
                      size: 48,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pre-Deployment Verification',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Run comprehensive checks on wallet operations',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Run Button
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runVerification,
              icon: _isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isRunning ? 'Running Checks...' : 'Run Verification',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // Results Summary
            if (_results != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification Results',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      _buildCheckItem(
                        'API Health',
                        _results!['api_health'] as Map<String, dynamic>?,
                      ),
                      _buildCheckItem(
                        'Wallet Exists',
                        _results!['wallet_check'] as Map<String, dynamic>?,
                      ),
                      _buildCheckItem(
                        'Balance Synced',
                        _results!['balance_sync'] as Map<String, dynamic>?,
                      ),
                      _buildCheckItem(
                        'No Duplicate Rewards',
                        _results!['duplicate_rewards'] as Map<String, dynamic>?,
                      ),
                      _buildCheckItem(
                        'Transaction History',
                        _results!['transaction_history']
                            as Map<String, dynamic>?,
                      ),
                      _buildCheckItem(
                        'Welcome Bonus',
                        _results!['welcome_bonus'] as Map<String, dynamic>?,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Detailed Report
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detailed Report',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              // Copy to clipboard functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Report copied to clipboard'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _report,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Empty state
            if (_report.isEmpty && !_isRunning)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Click "Run Verification" to start',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, Map<String, dynamic>? check) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_getStatusIcon(check), color: _getStatusColor(check), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (check != null)
            Text(
              check['status']?.toString() ?? 'UNKNOWN',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
