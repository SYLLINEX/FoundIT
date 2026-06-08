import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = cs.surface;
    final onCard = cs.onSurface;
    final subtleColor = cs.onSurfaceVariant;
    final dividerColor = cs.outline;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Contact Us Section
          _buildSectionTitle('Contact Us', onCard),
          const SizedBox(height: 8),
          _buildInfoCard(
            cardColor: cardColor,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'If you need further assistance or have inquiries, please feel free to contact the developer directly:',
                  style: TextStyle(fontSize: 14, color: subtleColor),
                ),
              ),
              Divider(height: 1, color: dividerColor),
              _buildContactRow(
                icon: PhosphorIconsFill.user,
                label: 'Developer',
                value: 'Sylvelter Judin',
                onCard: onCard,
                subtleColor: subtleColor,
              ),
              Divider(height: 1, indent: 48, color: dividerColor),
              _buildContactRow(
                icon: PhosphorIconsFill.whatsappLogo,
                iconColor: Colors.green,
                label: 'Whatsapp',
                value: '01125309019',
                onCard: onCard,
                subtleColor: subtleColor,
              ),
              Divider(height: 1, indent: 48, color: dividerColor),
              _buildContactRow(
                icon: PhosphorIconsFill.envelopeSimple,
                iconColor: Colors.blue,
                label: 'Email',
                value: 'sylvelter9@gmail.com',
                onCard: onCard,
                subtleColor: subtleColor,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // FAQ Section
          _buildSectionTitle('Frequently Asked Questions', onCard),
          const SizedBox(height: 8),
          _buildFAQCard(
            cardColor: cardColor,
            onCard: onCard,
            subtleColor: subtleColor,
            dividerColor: dividerColor,
            question: 'How do I report a missing item?',
            answer:
                'Go to the Home tab and tap on "Report Lost Item". Fill out the item details truthfully, including photos if available, and submit your report.',
          ),
          const SizedBox(height: 12),
          _buildFAQCard(
            cardColor: cardColor,
            onCard: onCard,
            subtleColor: subtleColor,
            dividerColor: dividerColor,
            question: 'How do I report an item I found?',
            answer:
                'Go to the Home tab and tap on "Report Found Item". Provide details and an image. Your report will be cross-checked with lost items using our AI system.',
          ),
          const SizedBox(height: 12),
          _buildFAQCard(
            cardColor: cardColor,
            onCard: onCard,
            subtleColor: subtleColor,
            dividerColor: dividerColor,
            question: 'What happens when a match is found?',
            answer:
                'Both parties will be notified. You can then use the built-in chat feature to communicate, verify ownership, and arrange a meetup to return the item securely.',
          ),
          const SizedBox(height: 12),
          _buildFAQCard(
            cardColor: cardColor,
            onCard: onCard,
            subtleColor: subtleColor,
            dividerColor: dividerColor,
            question: 'How do I know if the claimant is the real owner?',
            answer:
                'We encourage you to ask specific questions about the item that only the owner would know, or look at any identifying marks mentioned in the initial report. Never hand over an item until you are reasonably certain.',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color onCard) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: onCard.withOpacity(0.5),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children, required Color cardColor}) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color onCard,
    required Color subtleColor,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? subtleColor, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: subtleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: onCard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFAQCard({
    required String question,
    required String answer,
    required Color cardColor,
    required Color onCard,
    required Color subtleColor,
    required Color dividerColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          question,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: onCard,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: subtleColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
