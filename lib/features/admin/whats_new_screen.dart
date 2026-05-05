import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A model for a single release entry in the What's New screen.
class _Release {
  final String version;
  final List<_Feature> features;

  const _Release({
    required this.version,
    required this.features,
  });
}

class _Feature {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String description;

  const _Feature({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.description,
  });
}

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  // ── Release history (newest first) ─────────────────────────────────────
  static const List<_Release> _releases = [
    _Release(
      version: 'v1.6 – Latest',
      features: [
        _Feature(
          icon: PhosphorIconsFill.images,
          iconColor: Color(0xFF6366F1),
          title: 'Multi-Image Upload',
          description:
              'Report an item with up to 5 photos. Images are auto-compressed for fast uploads and stored securely in Firebase Storage.',
        ),
        _Feature(
          icon: PhosphorIconsFill.path,
          iconColor: Color(0xFF10B981),
          title: 'Feature Tour',
          description:
              'New users are greeted with an interactive overlay tour that highlights key app features, making onboarding effortless.',
        ),
        _Feature(
          icon: PhosphorIconsFill.robot,
          iconColor: Color(0xFFF59E0B),
          title: 'Enhanced AI Matching',
          description:
              'Multi-image reports now generate averaged visual fingerprints via MobileNetV3, improving match accuracy while staying compatible with legacy single-image reports.',
        ),
      ],
    ),
    _Release(
      version: 'v1.5',
      features: [
        _Feature(
          icon: PhosphorIconsFill.moon,
          iconColor: Color(0xFF8B5CF6),
          title: 'Dark Mode',
          description:
              'Full dark-theme support with theme-adaptive shimmer loading and consistent colours across every screen, including admin panels.',
        ),
        _Feature(
          icon: PhosphorIconsFill.shieldWarning,
          iconColor: Color(0xFFEF4444),
          title: 'Cancellation & Relisting',
          description:
              'Reports that fail return can now be cancelled and automatically relisted, with proper Firestore rule enforcement.',
        ),
        _Feature(
          icon: PhosphorIconsFill.bellRinging,
          iconColor: Color(0xFF06B6D4),
          title: 'Dynamic Alerts',
          description:
              'Real-time push notifications via FCM with a resend cooldown system and improved token lifecycle management on sign-out.',
        ),
      ],
    ),
    _Release(
      version: 'v1.4',
      features: [
        _Feature(
          icon: PhosphorIconsFill.mapPin,
          iconColor: Color(0xFF10B981),
          title: 'Map Overhaul',
          description:
              'All map controls consolidated into a single FAB with 10 km proximity filtering for both the map and the main dashboard.',
        ),
        _Feature(
          icon: PhosphorIconsFill.chatCircleText,
          iconColor: Color(0xFF3B82F6),
          title: 'Swipe-to-Reply Chat',
          description:
              'In-app chat supports swipe-to-reply, message un-reaction, and smooth send-loading animations.',
        ),
        _Feature(
          icon: PhosphorIconsFill.userCircleCheck,
          iconColor: Color(0xFF6366F1),
          title: 'Admin Claim Review',
          description:
              'Admins can now review claim disputes with an AI similarity comparison panel for fair and accurate decisions.',
        ),
      ],
    ),
    _Release(
      version: 'v1.3',
      features: [
        _Feature(
          icon: PhosphorIconsFill.brain,
          iconColor: Color(0xFFF59E0B),
          title: 'AI Item Classification',
          description:
              'Fine-tuned MobileNetV3 model automatically classifies uploaded items and suggests the correct category, with manual override support.',
        ),
        _Feature(
          icon: PhosphorIconsFill.fingerprint,
          iconColor: Color(0xFF8B5CF6),
          title: 'Onboarding Flow',
          description:
              'A polished onboarding screen guides first-time users through the app\'s core concept before they reach the home screen.',
        ),
        _Feature(
          icon: PhosphorIconsFill.circleNotch,
          iconColor: Color(0xFF64748B),
          title: 'Skeleton Loading',
          description:
              'Dashboard and reports screens now display shimmer skeleton placeholders while data is fetched, eliminating blank flashes.',
        ),
      ],
    ),
    _Release(
      version: 'v1.2',
      features: [
        _Feature(
          icon: PhosphorIconsFill.question,
          iconColor: Color(0xFF06B6D4),
          title: 'Help & Support',
          description:
              'Dedicated Help & Support, Terms of Service, and About sections added to both user and admin profile screens.',
        ),
        _Feature(
          icon: PhosphorIconsFill.lock,
          iconColor: Color(0xFFEF4444),
          title: 'Forgot Password',
          description:
              'Password reset flow with email verification and an improved splash screen with dynamic loading messages.',
        ),
      ],
    ),
    _Release(
      version: 'v1.0 – Initial Release',
      features: [
        _Feature(
          icon: PhosphorIconsFill.rocket,
          iconColor: Color(0xFF10B981),
          title: 'Core Platform Launch',
          description:
              'FoundIT launched with lost & found reporting, AI-powered item matching, real-time chat, push notifications, and an admin dashboard.',
        ),
        _Feature(
          icon: PhosphorIconsFill.googleLogo,
          iconColor: Color(0xFF3B82F6),
          title: 'Google Sign-In',
          description:
              'Secure authentication via Firebase Auth with Google Sign-In support for UNIMAS students and staff.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("What's New"),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        itemCount: _releases.length,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final release = _releases[index];
          return _buildReleaseCard(context, cs, release);
        },
      ),
    );
  }

  Widget _buildReleaseCard(
    BuildContext context,
    ColorScheme cs,
    _Release release,
  ) {
    final isLatest = release.version.contains('Latest');

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          // ── Release header ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: isLatest
                  ? const LinearGradient(
                      colors: [Color(0xFF413F54), Color(0xFF6366F1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: isLatest ? null : cs.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isLatest
                      ? PhosphorIconsFill.sparkle
                      : PhosphorIconsRegular.clockCounterClockwise,
                  color: isLatest
                      ? Colors.white
                      : cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    release.version,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isLatest ? Colors.white : cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Feature list ─────────────────────────────────────────
          ...release.features.asMap().entries.map((entry) {
            final i = entry.key;
            final feature = entry.value;
            return Column(
              children: [
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: cs.outlineVariant,
                  ),
                _buildFeatureRow(context, cs, feature),
              ],
            );
          }),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    ColorScheme cs,
    _Feature feature,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (feature.iconColor ?? cs.primary).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              feature.icon,
              color: feature.iconColor ?? cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
