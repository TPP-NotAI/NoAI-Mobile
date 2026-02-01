import 'package:flutter/material.dart';
import 'package:noai/screens/support/contact_support_screen.dart'; // Ensure the correct import path

class BannedScreen extends StatelessWidget {
  const BannedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Banned')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Your account has been banned.',
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
