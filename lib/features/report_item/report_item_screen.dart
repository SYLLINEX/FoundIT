import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart'; // Assuming google_fonts is available, let's use default bold if not
import 'report_item_form_screen.dart';

class ReportItemScreen extends StatelessWidget {
  const ReportItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Light grayish-blue background
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(PhosphorIconsRegular.caretLeft, size: 18, color: Color(0xFF374151)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'What happened?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E384D),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Help us understand the situation\nso we can process your report\ncorrectly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),
              _buildOptionCard(
                context,
                title: 'I Lost Something',
                subtitle: "Report an item you've misplaced and\nneed help finding.",
                icon: PhosphorIconsRegular.question,
                iconColor: Colors.white,
                circleBgColor: const Color(0xFFE11D48),
                lightCircleBgolor: const Color(0xFFFEE2E2),
                reportType: 'Lost',
              ),
              const SizedBox(height: 24),
              _buildOptionCard(
                context,
                title: 'I Found Something',
                subtitle: "Report an item you've discovered to\nhelp return it.",
                icon: PhosphorIconsRegular.navigationArrow,
                iconColor: Colors.white,
                circleBgColor: const Color(0xFF10B981),
                lightCircleBgolor: const Color(0xFFD1FAE5),
                reportType: 'Found',
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color circleBgColor,
    required Color lightCircleBgolor,
    required String reportType,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportItemFormScreen(reportType: reportType),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightCircleBgolor,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: circleBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
