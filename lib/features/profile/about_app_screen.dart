import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: AppBar(
        title: const Text('About FoundIT', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF413F55),
        iconTheme: const IconThemeData(color: Colors.white),
        scrolledUnderElevation: 0,
      ),
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
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/foundit_logo.png',
                    height: 80,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(PhosphorIconsFill.magnifyingGlass, size: 80, color: Color(0xFF413F55)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'FoundIT',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF262532),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.0.0 (Build 42)',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
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

          // Brief Description
          _buildInfoCard(
            title: 'About the App',
            icon: PhosphorIconsFill.info,
            iconColor: Colors.blue,
            content: 'FoundIT is an intelligent lost and found management system tailored for the UNIMAS community. It leverages AI and machine learning to seamlessly cross-reference and match lost and found item reports, minimizing the headache of locating misplaced belongings.',
          ),
          const SizedBox(height: 16),

          // Developer Info
          _buildInfoCard(
            title: 'Developer',
            icon: PhosphorIconsFill.code,
            iconColor: Colors.orange,
            content: 'Built with passion by Sylvelter Judin as a Final Year Project (FYP). Dedicated to improving the campus experience through modern technology.',
          ),
          const SizedBox(height: 16),

          // How AI Works
          _buildInfoCard(
            title: 'How the AI Works',
            icon: PhosphorIconsFill.brain,
            iconColor: Colors.teal,
            content: 'FoundIT employs a dual-layered AI matching engine. First, an on-device TensorFlow Lite model (MobileNetV3) extracts deep visual features from item photos to compare structural similarities. Simultaneously, our cloud functions run NLP (Natural Language Processing) techniques over the item titles and descriptions. The system fuses these visual and textual scores to accurately recommend potential matches between lost and found items!',
          ),
          const SizedBox(height: 16),

          // Architecture & Tech Stack (The "Cool" part)
          _buildTechStackCard(),

          const SizedBox(height: 40),
          const Center(
            child: Text(
              '© 2026 UNIMAS FoundIT. All rights reserved.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF262532),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechStackCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(PhosphorIconsFill.cpu, color: Colors.purple, size: 22),
              SizedBox(width: 8),
              Text(
                'Architecture & Tech Stack',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF262532),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTechRow(
            category: 'Frontend',
            techs: ['Flutter', 'Dart', 'Clean Architecture'],
          ),
          const Divider(height: 24, color: Color(0xFFEEEDF2)),
          _buildTechRow(
            category: 'Backend (BaaS)',
            techs: ['Firebase Auth', 'Firestore', 'Cloud Storage'],
          ),
          const Divider(height: 24, color: Color(0xFFEEEDF2)),
          _buildTechRow(
            category: 'AI & Inference',
            techs: ['TensorFlow Lite', 'MobileNetV3', 'NLP Similarity Matching'],
          ),
          const Divider(height: 24, color: Color(0xFFEEEDF2)),
          _buildTechRow(
            category: 'Automation',
            techs: ['Cloud Functions', 'FCM Push Notifications'],
          ),
        ],
      ),
    );
  }

  Widget _buildTechRow({
    required String category,
    required List<String> techs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
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
                color: const Color(0xFFF2F2F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDDCE5)),
              ),
              child: Text(
                tech,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3E3D52),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
