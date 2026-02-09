import 'package:flutter/material.dart';
import 'package:rooverse/screens/support/contact_support_screen.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import '../../utils/responsive_extensions.dart';

class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Suspended')),
      body: Center(
        child: Padding(
          padding: AppSpacing.responsiveAll(context, AppSpacing.largePlus),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                size: AppTypography.responsiveIconSize(context, 64),
                color: Colors.red,
              ),
              SizedBox(height: AppSpacing.standard.responsive(context)),
              Text(
                'Your account has been suspended.',
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(context, AppTypography.smallHeading),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.standard.responsive(context)),
              SizedBox(
                width: double.infinity,
                height: 48.responsive(context, min: 44, max: 52),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContactSupportScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(context, AppTypography.base),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
