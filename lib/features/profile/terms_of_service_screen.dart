import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = cs.surface;
    final onCard = cs.onSurface;
    final subtleColor = cs.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/foundit_logo.png',
                      height: 100,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.shield_outlined, size: 80, color: cs.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FoundIT',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: onCard,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Terms of Service',
                      style: TextStyle(
                        fontSize: 16,
                        color: subtleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSection(
                title: '1. Acceptance of Terms',
                content:
                    'By accessing and using this application, you accept and agree to be bound by the terms and provisions of this agreement. In addition, when using these particular services, you shall be subject to any posted guidelines or rules applicable to such services.',
                onCard: onCard,
                subtleColor: subtleColor,
              ),
              _buildSection(
                title: '2. Description of Service',
                content:
                    'FoundIT provides a platform for users to report lost and found items within the community. We strive to assist in the recovery process using AI matching, but we do not guarantee the successful return of any item.',
                onCard: onCard,
                subtleColor: subtleColor,
              ),
              _buildSection(
                title: '3. User Conduct',
                content:
                    'You agree to use the service only for lawful purposes. You are solely responsible for the knowledge and accuracy of the information you provide in reports. Posting false, misleading, or inappropriate content is strictly prohibited and will result in the suspension of your account.',
                onCard: onCard,
                subtleColor: subtleColor,
              ),
              _buildSection(
                title: '4. Privacy Policy',
                content:
                    'Your privacy is important to us. We will protect the personal data you share during registration and the reporting process. However, to facilitate the return of items, necessary contact information may be shared between the finder and the owner during the meetup arrangement.',
                onCard: onCard,
                subtleColor: subtleColor,
              ),
              _buildSection(
                title: '5. Limitation of Liability',
                content:
                    'FoundIT, the developer, and any associated parties shall not be held liable for any direct, indirect, incidental, or consequential damages resulting from the use or inability to use the service, including but not limited to the loss of items, damages during meetups, or any interactions between users.',
                onCard: onCard,
                subtleColor: subtleColor,
              ),
              _buildSection(
                title: '6. Modifications to Service',
                content:
                    'We reserve the right at any time and from time to time to modify or discontinue, temporarily or permanently, the Service (or any part thereof) with or without notice.',
                onCard: onCard,
                subtleColor: subtleColor,
              ),

              const SizedBox(height: 40),

              Center(
                child: Text(
                  'Last updated: April 2026',
                  style: TextStyle(
                    color: subtleColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required Color onCard,
    required Color subtleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: onCard,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: subtleColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
