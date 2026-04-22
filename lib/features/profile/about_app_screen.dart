import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = cs.surface;
    final onCard = cs.onSurface;
    final subtleColor = cs.onSurfaceVariant;
    final dividerColor = cs.outline;
    final tagBg = cs.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(title: const Text('About FoundIT')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        children: [
          // App Logo and Header Info
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/foundit_logo.png',
                    height: 80,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(PhosphorIconsFill.magnifyingGlass, size: 80, color: cs.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'FoundIT',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: onCard,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 (Build 42)',
                  style: TextStyle(color: subtleColor, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Beta Release',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          _buildInfoCard(
            context: context,
            cardColor: cardColor,
            onCard: onCard,
            subtleColor: subtleColor,
            title: 'About the App',
            icon: PhosphorIconsFill.info,
            iconColor: Colors.blue,
            content:
                'FoundIT is an intelligent lost and found management system tailored for the UNIMAS community. It leverages AI and machine learning to seamlessly cross-reference and match lost and found item reports, minimizing the headache of locating misplaced belongings.',
          ),
          const SizedBox(height: 16),

          _buildInfoCard(
            context: context,
            cardColor: cardColor,
            onCard: onCard,
            subtleColor: subtleColor,
            title: 'Developer',
            icon: PhosphorIconsFill.code,
            iconColor: Colors.orange,
            content:
                'Built with passion by Sylvelter Judin as a Final Year Project (FYP). Dedicated to improving the campus experience through modern technology.',
          ),
          const SizedBox(height: 16),

          _buildInfoCard(
            context: context,
            cardColor: cardColor,
            onCard: onCard,
            subtleColor: subtleColor,
            title: 'How the AI Works',
            icon: PhosphorIconsFill.brain,
            iconColor: Colors.teal,
            content:
                'FoundIT employs a dual-layered AI matching engine. First, an on-device TensorFlow Lite model (MobileNetV3) extracts deep visual features from item photos to compare structural similarities. Simultaneously, our cloud functions run NLP (Natural Language Processing) techniques over the item titles and descriptions. The system fuses these visual and textual scores to accurately recommend potential matches between lost and found items!',
          ),
          const SizedBox(height: 16),

          _buildTechStackCard(
            cardColor: cardColor,
            onCard: onCard,
            subtleColor: subtleColor,
            tagBg: tagBg,
            dividerColor: dividerColor,
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              '© 2026 UNIMAS FoundIT. All rights reserved.',
              style: TextStyle(color: subtleColor, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required Color cardColor,
    required Color onCard,
    required Color subtleColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onCard,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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

  Widget _buildTechStackCard({
    required Color cardColor,
    required Color onCard,
    required Color subtleColor,
    required Color tagBg,
    required Color dividerColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsFill.cpu, color: Colors.purple, size: 22),
              const SizedBox(width: 8),
              Text(
                'Architecture & Tech Stack',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onCard,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTechRow(
            category: 'Frontend',
            techs: ['Flutter', 'Dart', 'Clean Architecture'],
            subtleColor: subtleColor,
            tagBg: tagBg,
            onCard: onCard,
          ),
          Divider(height: 24, color: dividerColor),
          _buildTechRow(
            category: 'Backend (BaaS)',
            techs: ['Firebase Auth', 'Firestore', 'Cloud Storage'],
            subtleColor: subtleColor,
            tagBg: tagBg,
            onCard: onCard,
          ),
          Divider(height: 24, color: dividerColor),
          _buildTechRow(
            category: 'AI & Inference',
            techs: ['TensorFlow Lite', 'MobileNetV3', 'NLP Similarity Matching'],
            subtleColor: subtleColor,
            tagBg: tagBg,
            onCard: onCard,
          ),
          Divider(height: 24, color: dividerColor),
          _buildTechRow(
            category: 'Automation',
            techs: ['Cloud Functions', 'FCM Push Notifications'],
            subtleColor: subtleColor,
            tagBg: tagBg,
            onCard: onCard,
          ),
        ],
      ),
    );
  }

  Widget _buildTechRow({
    required String category,
    required List<String> techs,
    required Color subtleColor,
    required Color tagBg,
    required Color onCard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: subtleColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: techs.map((tech) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tagBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tech,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: onCard,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
