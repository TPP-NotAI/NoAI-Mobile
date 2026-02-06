import 'package:flutter/material.dart';
import 'package:rooverse/screens/support/contact_support_screen.dart';

class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Suspended')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Your account has been suspended.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to the Contact Support screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactSupportScreen(),
                  ),
                );
              },
              child: const Text('Contact Support'),
            ),
          ],
        ),
      ),
    );
  }
}
