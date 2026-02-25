import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../repositories/support_ticket_repository.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final Random _random = Random();
  final SupportTicketRepository _supportTicketRepository =
      SupportTicketRepository();

  String _selectedCategory = 'general';
  String _selectedPriority = 'normal';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitSupport() async {
    if (_isSubmitting) return;
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields'.tr(context)),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final ticketId = await _supportTicketRepository.createTicket(
      subject: _subjectController.text.trim(),
      category: _selectedCategory,
      priority: _selectedPriority,
      message: _messageController.text.trim(),
      requesterName: _nameController.text.trim(),
      requesterEmail: _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit ticket. Please try again.'.tr(context)),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final ticketReference = _toTicketReference(ticketId);
    _resetForm();
    FocusScope.of(context).unfocus();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surface,
          title: Text('Ticket Submitted'.tr(context),
            style: TextStyle(color: scheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('We received your request and will respond within 24 hours.'.tr(context),
                style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
              ),
              SizedBox(height: 12),
              Text('Ticket reference: $ticketReference'.tr(context),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.close, style: TextStyle(color: scheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _subjectController.clear();
    _messageController.clear();

    if (!mounted) return;
    setState(() {
      _selectedCategory = 'general';
      _selectedPriority = 'normal';
    });
  }

  String _generateTicketReference() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer('ROO-');
    for (var i = 0; i < 6; i++) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  String _toTicketReference(String ticketId) {
    final compact = ticketId.replaceAll('-', '').toUpperCase();
    if (compact.length < 6) return _generateTicketReference();
    return 'ROO-${compact.substring(0, 6)}';
  }

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
        title: Text('Contact Support'.tr(context),
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.headset_mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('We\'re Here to Help'.tr(context),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('Average response time: 2-4 hours'.tr(context),
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            _buildInputField(
              label: 'Name',
              controller: _nameController,
              icon: Icons.person,
              hint: 'Your full name',
              scheme: scheme,
            ),
            SizedBox(height: 20),
            _buildInputField(
              label: 'Email',
              controller: _emailController,
              icon: Icons.email,
              hint: 'your@email.com',
              keyboardType: TextInputType.emailAddress,
              scheme: scheme,
            ),

            SizedBox(height: 20),

            // Category
            _buildDropdown(
              label: 'Category',
              value: _selectedCategory,
              items: [
                DropdownMenuItem(
                  value: 'general',
                  child: Text('General Inquiry'.tr(context)),
                ),
                DropdownMenuItem(
                  value: 'account',
                  child: Text('Account Issue'.tr(context)),
                ),
                DropdownMenuItem(
                  value: 'moderation',
                  child: Text('Moderation Appeal'.tr(context)),
                ),
                DropdownMenuItem(
                  value: 'roocoin',
                  child: Text('Roobyte / Wallet'.tr(context)),
                ),
                DropdownMenuItem(
                  value: 'technical',
                  child: Text('Technical Problem'.tr(context)),
                ),
                DropdownMenuItem(value: 'report', child: Text('Report Abuse'.tr(context))),
                DropdownMenuItem(value: 'other', child: Text('Other'.tr(context))),
              ],
              onChanged: (v) => setState(() => _selectedCategory = v),
              scheme: scheme,
            ),

            SizedBox(height: 20),

            // Priority
            Text('Priority'.tr(context),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: scheme.onBackground,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPriorityOption(
                    'Low',
                    'low',
                    const Color(0xFF10B981),
                    scheme,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildPriorityOption(
                    'Normal',
                    'normal',
                    const Color(0xFF3B82F6),
                    scheme,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildPriorityOption(
                    'High',
                    'high',
                    const Color(0xFFEF4444),
                    scheme,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            _buildInputField(
              label: 'Subject',
              controller: _subjectController,
              icon: Icons.subject,
              hint: 'Brief description of your issue',
              scheme: scheme,
            ),
            SizedBox(height: 20),
            _buildInputField(
              label: 'Message',
              controller: _messageController,
              icon: Icons.message,
              hint: 'Please describe your issue in detail...',
              maxLines: 8,
              maxLength: 1000,
              scheme: scheme,
            ),

            SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitSupport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSubmitting)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(Icons.send, size: 20),
                    SizedBox(width: 8),
                    Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Ticket',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required ColorScheme scheme,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: scheme.onBackground,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            style: TextStyle(color: scheme.onSurface, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
              prefixIcon: Icon(icon, color: scheme.onSurface.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
    required ColorScheme scheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: scheme.onBackground,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: scheme.surface,
              icon: Icon(Icons.arrow_drop_down, color: scheme.onSurface),
              style: TextStyle(color: scheme.onSurface, fontSize: 16),
              onChanged: (v) => onChanged(v!),
              items: items,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityOption(
    String label,
    String value,
    Color color,
    ColorScheme scheme,
  ) {
    final isSelected = _selectedPriority == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPriority = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : scheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? color : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

