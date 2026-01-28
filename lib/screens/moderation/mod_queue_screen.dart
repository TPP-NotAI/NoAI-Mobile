import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class ModQueueScreen extends StatefulWidget {
  const ModQueueScreen({super.key});

  @override
  State<ModQueueScreen> createState() => _ModQueueScreenState();
}

class _ModQueueScreenState extends State<ModQueueScreen> {
  String _selectedFilter = 'Priority';
  String _selectedSort = 'Most Reported';
  String _selectedType = 'Violation Type';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mod Queue',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Stats Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.warning,
                    iconColor: Colors.orange,
                    label: 'BACKLOG',
                    value: '142',
                    subtitle: '+12 since last login',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.check_circle,
                    iconColor: Colors.blue,
                    label: 'DAILY ACTIONS',
                    value: '45',
                    subtitle: 'Target: 100',
                  ),
                ),
              ],
            ),
          ),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  label: _selectedFilter,
                  isPrimary: true,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: _selectedSort,
                  isPrimary: false,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: _selectedType,
                  isPrimary: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Queue Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildQueueItem(
                  context,
                  violation: 'Impersonation',
                  priority: 'High Priority',
                  reportCount: '12 Reports',
                  username: '@cryptokid99',
                  accountAge: '3d',
                  isVerified: false,
                  rooBalance: '0.00 ROO',
                  content:
                      'Hey guys, I am an official admin for NOAI. Please DM me your wallet keys to verify your humanity status immediately or you will be banned! 🚨',
                  hasImage: true,
                  aiAnalysis:
                      'Pattern matches known phishing scripts (98% confidence). User has sent 400 DMs in the last hour.',
                  violationColor: Colors.red,
                ),
                const SizedBox(height: 12),
                _buildQueueItem(
                  context,
                  violation: 'Graphic Violence',
                  priority: null,
                  reportCount: null,
                  username: '@real_human_1',
                  accountAge: null,
                  isVerified: true,
                  rooBalance: '1.2k ROO',
                  content: null,
                  hasImage: false,
                  aiAnalysis: null,
                  violationColor: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isPrimary,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? AppColors.primary : scheme.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : scheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: isPrimary ? Colors.white : scheme.onSurface.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItem(
    BuildContext context, {
    required String violation,
    String? priority,
    String? reportCount,
    required String username,
    String? accountAge,
    required bool isVerified,
    required String rooBalance,
    String? content,
    required bool hasImage,
    String? aiAnalysis,
    required Color violationColor,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Violation Header
          Row(
            children: [
              Icon(Icons.error, color: violationColor, size: 18),
              const SizedBox(width: 8),
              Text(
                violation,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: violationColor,
                ),
              ),
              const Spacer(),
              if (priority != null && reportCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: violationColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$priority • $reportCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: violationColor,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // User Info
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.onSurface.withOpacity(0.1),
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (accountAge != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Acc age: $accountAge',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (!isVerified)
                          Text(
                            'Unverified',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          )
                        else
                          Row(
                            children: [
                              Icon(Icons.verified, size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Verified Human',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.currency_bitcoin, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      rooBalance,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (content != null) ...[
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ],

          if (hasImage) ...[
            const SizedBox(height: 12),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: scheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.visibility_off,
                      size: 40,
                      color: scheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to Reveal Image',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'Suspected Scam Content',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (aiAnalysis != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.psychology, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI CONTEXT ANALYSIS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          aiAnalysis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.block, size: 18),
                  label: Text('Ban User'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.delete, size: 18),
                  label: Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.check, size: 18),
                  label: Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
