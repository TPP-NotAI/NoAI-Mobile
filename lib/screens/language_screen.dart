import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../config/app_colors.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final languageProvider = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text('Language', style: TextStyle(color: scheme.onSurface)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select your preferred language',
              style: TextStyle(
                fontSize: 16,
                color: scheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          ...languageProvider.supportedLanguages.map((language) {
            final isSelected =
                language['code'] == languageProvider.currentLanguage;
            return _buildLanguageTile(
              context,
              code: language['code']!,
              name: language['name']!,
              isSelected: isSelected,
              onTap: () {
                languageProvider.setLanguage(language['code']!);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context, {
    required String code,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : scheme.outline.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.primary, size: 24),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
