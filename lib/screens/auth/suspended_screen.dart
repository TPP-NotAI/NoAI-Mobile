import 'package:flutter/material.dart';
import 'package:rooverse/screens/support/contact_support_screen.dart';
import '../../config/app_spacing.dart';
import '../../config/app_typography.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_extensions.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Account Suspended'.tr(context))),
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
              Text('Your account has been suspended.'.tr(context),
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    AppTypography.smallHeading,
                  ),
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
                  child: Text('Contact Support'.tr(context),
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.base,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.standard.responsive(context)),
              SizedBox(
                width: double.infinity,
                height: 48.responsive(context, min: 44, max: 52),
                child: OutlinedButton(
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    await auth.signOut();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    foregroundColor: Colors.orange,
                  ),
                  child: Text('Log Out'.tr(context),
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        AppTypography.base,
                      ),
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
