import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../../widgets/theme_aware_shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/item_model.dart';
import '../../../models/claim_model.dart';
import '../../../services/ai_service.dart';
import '../../../widgets/found_it_loading_indicator.dart';
import '../../../widgets/app_confirmation_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen image viewer
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated arc gauge (overall score)
// ─────────────────────────────────────────────────────────────────────────────
class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color trackColor;

  _ArcGaugePainter(
      {required this.progress,
      required this.arcColor,
      required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = trackColor
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    canvas.drawArc(
        rect,
        start,
        sweep * progress,
        false,
        Paint()
          ..color = arcColor
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}

class _ArcGauge extends StatefulWidget {
  final double percentage;
  const _ArcGauge({required this.percentage});

  @override
  State<_ArcGauge> createState() => _ArcGaugeState();
}

class _ArcGaugeState extends State<_ArcGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = Tween<double>(begin: 0, end: widget.percentage / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_ArcGauge old) {
    super.didUpdateWidget(old);
    if (old.percentage != widget.percentage) {
      _anim = Tween<double>(begin: _anim.value, end: widget.percentage / 100)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _color(double p) {
    if (p >= 70) return const Color(0xFF10B981);
    if (p >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _label(double p) {
    if (p >= 70) return 'Strong Match';
    if (p >= 40) return 'Moderate Match';
    return 'Weak Match';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(widget.percentage);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        return Column(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _ArcGaugePainter(
                      progress: v,
                      arcColor: color,
                      trackColor: color.withValues(alpha: 0.12),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(v * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Overall',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _label(widget.percentage),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated horizontal bar for each sub-score category
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryBar extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final double percentage;
  final double weight; // e.g. 0.50

  const _CategoryBar({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.percentage,
    required this.weight,
  });

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.percentage / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    // Stagger based on hash so bars don't all animate simultaneously
    Future.delayed(Duration(milliseconds: (widget.label.hashCode % 5) * 80),
        () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_CategoryBar old) {
    super.didUpdateWidget(old);
    if (old.percentage != widget.percentage) {
      _anim = Tween<double>(begin: _anim.value, end: widget.percentage / 100)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _barColor(double p) {
    if (p >= 70) return const Color(0xFF10B981);
    if (p >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _barColor(widget.percentage);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 17),
              ),
              const SizedBox(width: 12),
              // Bar + labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  )),
                              Text(widget.sublabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Score + weight badge
                        Row(
                          children: [
                            Text(
                              '${(v * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: barColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '×${(widget.weight * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 7,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen  (StatefulWidget — needs to fetch linked report & compute scores)
// ─────────────────────────────────────────────────────────────────────────────
class ClaimReviewScreen extends StatefulWidget {
  final ItemModel targetItem;
  final ClaimModel claim;
  final String claimerName;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ClaimReviewScreen({
    super.key,
    required this.targetItem,
    required this.claim,
    required this.claimerName,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<ClaimReviewScreen> createState() => _ClaimReviewScreenState();
}

class _ClaimReviewScreenState extends State<ClaimReviewScreen> {
  final AIService _aiService = AIService();

  ItemModel? _linkedReport;
  SimilarityBreakdown? _breakdown;
  bool _loadingLinked = false;

  @override
  void initState() {
    super.initState();
    _fetchLinkedReport();
  }

  Future<void> _fetchLinkedReport() async {
    final id = widget.claim.linkedLostReportId;
    if (id == null || id.isEmpty) {
      if (widget.claim.claimantAiScoreVector != null) {
        final dummyLinked = ItemModel(
          itemId: 'dummy',
          userId: widget.claim.claimantId,
          postType: widget.claim.isFoundTip ? 'Lost' : 'Found',
          category: widget.targetItem.category, 
          title: 'Claimant Proof',
          description: widget.claim.proofDesc,
          imageUrl: (widget.claim.proofImageUrls?.isNotEmpty == true) ? widget.claim.proofImageUrls!.first : '',
          locationName: 'Not Provided',
          status: 'Pending',
          aiLabels: widget.claim.claimantAiLabels ?? [],
          aiScoreVector: widget.claim.claimantAiScoreVector ?? [],
          timestamp: widget.claim.timestamp,
          eventDate: widget.claim.timestamp,
        );

        final breakdown = widget.claim.isFoundTip
            ? _aiService.getSimilarityBreakdown(
                linkedLostReport: widget.targetItem,
                claimTargetItem: dummyLinked,
                claimDescription: widget.claim.proofDesc,
              )
            : _aiService.getSimilarityBreakdown(
                linkedLostReport: dummyLinked,
                claimTargetItem: widget.targetItem,
                claimDescription: widget.claim.proofDesc,
              );

        setState(() {
          _linkedReport = dummyLinked;
          _breakdown = breakdown;
        });
      }
      return;
    }

    setState(() => _loadingLinked = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('items')
          .doc(id)
          .get();
      final data = snap.data();
      if (data == null || !mounted) return;

      final linked = ItemModel.fromMap(snap.id, data);
      final breakdown = widget.claim.isFoundTip
          ? _aiService.getSimilarityBreakdown(
              linkedLostReport: widget.targetItem,
              claimTargetItem: linked,
              claimDescription: widget.claim.proofDesc,
            )
          : _aiService.getSimilarityBreakdown(
              linkedLostReport: linked,
              claimTargetItem: widget.targetItem,
              claimDescription: widget.claim.proofDesc,
            );

      setState(() {
        _linkedReport = linked;
        _breakdown = breakdown;
      });
    } finally {
      if (mounted) setState(() => _loadingLinked = false);
    }
  }

  void _openFullScreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(imageUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Claim Review',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Claimer header ────────────────────────────────────
                  _ClaimerHeaderCard(name: widget.claimerName),
                  const SizedBox(height: 16),

                  // ── Proof description ────────────────────────────────
                  _SectionCard(
                    icon: PhosphorIconsRegular.note,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Proof Provided by Claimer',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.claim.proofDesc.isEmpty
                            ? '(No description provided)'
                            : widget.claim.proofDesc,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Extra proof images ───────────────────────────────
                  if (widget.claim.proofImageUrls != null &&
                      widget.claim.proofImageUrls!.isNotEmpty) ...[
                    _SectionCard(
                      icon: PhosphorIconsRegular.receipt,
                      iconColor: const Color(0xFF0EA5E9),
                      title: 'Supporting Evidence',
                      subtitle: 'Tap any photo to view full screen',
                      child: _ProofImageGrid(
                        urls: widget.claim.proofImageUrls!,
                        onTap: _openFullScreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── AI Score section ──────────────────────────────────
                  _buildAIScoreSection(),
                  const SizedBox(height: 16),

                  // ── Side-by-side comparison ───────────────────────────
                  _SectionCard(
                    icon: PhosphorIconsRegular.arrowsLeftRight,
                    iconColor: const Color(0xFF10B981),
                    title: 'Item Comparison',
                    child: _loadingLinked
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: FoundItLoadingIndicator()),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ComparisonPanel(
                                  heading: widget.claim.isFoundTip ? 'LOST Item' : 'FOUND Item',
                                  item: widget.targetItem,
                                  accent: const Color(0xFF2563EB),
                                  onImageTap: _openFullScreen,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _linkedReport != null
                                    ? _ComparisonPanel(
                                        heading: _linkedReport!.itemId == 'dummy'
                                            ? 'Claimant Proof Image'
                                            : (widget.claim.isFoundTip ? 'Finder\'s Proof / FOUND Item' : 'LOST Report'),
                                        item: _linkedReport!,
                                        accent: const Color(0xFFDC2626),
                                        onImageTap: _openFullScreen,
                                      )
                                    : const _ComparisonPlaceholder(),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Sticky action bar ───────────────────────────────────────
          _ActionBar(
            onReject: () async {
              final reason = await showAppInputDialog(
                context: context,
                title: 'Reject Claim?',
                message: 'Please provide a reason for rejecting this claim.',
                hintText: 'e.g., Proof is insufficient',
                confirmText: 'Reject',
                confirmColor: Colors.red.shade700,
              );
              if (reason != null && reason.trim().isNotEmpty) {
                widget.onReject();
                if (mounted) Navigator.pop(context);
              }
            },
            onApprove: () async {
              final confirmed = await showAppConfirmationDialog<bool>(
                context: context,
                title: 'Approve Claim?',
                message: 'The item will be reserved for this claimant.',
                confirmText: 'Approve',
                confirmColor: AppColors.statusResolved,
              );
              if (confirmed == true) {
                widget.onApprove();
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── AI score section builder ──────────────────────────────────────────────
  Widget _buildAIScoreSection() {
    final bd = _breakdown;
    // Use stored score as fallback if breakdown not available (no linked report)
    final overallPct = bd?.overall ?? widget.claim.similarityScore ?? 0.0;
    final hasLinked = _linkedReport != null;

    return _SectionCard(
      icon: PhosphorIconsRegular.sparkle,
      iconColor: const Color(0xFF8B5CF6),
      title: 'AI Similarity Analysis',
      subtitle: hasLinked
          ? 'Breakdown across 6 comparison dimensions'
          : 'Overall score — link a LOST report for full breakdown',
      child: Column(
        children: [
          // ── Overall arc gauge (centred) ──────────────────────────────
          Center(child: _ArcGauge(percentage: overallPct)),

          if (hasLinked && bd != null) ...[
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: Colors.grey.shade100,
            ),
            const SizedBox(height: 20),

            // ── Divider label ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Score Breakdown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '(weight × raw score = contribution)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Per-category bars ──────────────────────────────────────
            _CategoryBar(
              icon: PhosphorIconsRegular.eye,
              iconColor: const Color(0xFF6366F1),
              label: 'Visual Similarity',
              sublabel: 'AI image-vector cosine match',
              percentage: bd.visual,
              weight: AIService.visualWeight,
            ),
            _CategoryBar(
              icon: PhosphorIconsRegular.textAlignLeft,
              iconColor: const Color(0xFF0EA5E9),
              label: 'Description Match',
              sublabel: 'Title & description token overlap',
              percentage: bd.description,
              weight: AIService.textWeight,
            ),
            _CategoryBar(
              icon: PhosphorIconsRegular.clock,
              iconColor: const Color(0xFFF59E0B),
              label: 'Time Proximity',
              sublabel: 'How close the lost & found dates are',
              percentage: bd.time,
              weight: AIService.timeWeight,
            ),
            _CategoryBar(
              icon: PhosphorIconsRegular.mapPin,
              iconColor: const Color(0xFF10B981),
              label: 'Location Proximity',
              sublabel: 'Geographic distance between reports',
              percentage: bd.location,
              weight: AIService.locationWeight,
            ),
            _CategoryBar(
              icon: PhosphorIconsRegular.tag,
              iconColor: const Color(0xFFEC4899),
              label: 'AI Label Overlap',
              sublabel: 'Shared recognition labels (Jaccard)',
              percentage: bd.labels,
              weight: AIService.labelsWeight,
            ),
            _CategoryBar(
              icon: PhosphorIconsRegular.squaresFour,
              iconColor: const Color(0xFF64748B),
              label: 'Category Match',
              sublabel: 'Exact item category',
              percentage: bd.category,
              weight: AIService.categoryWeight,
            ),
          ],

          // ── Warning banner ─────────────────────────────────────────
          if (overallPct < AIService.lowSimilarityThreshold) ...[
            const SizedBox(height: 14),
            _WarningBanner(
              message:
                  'Low AI similarity score. Review the claimer\'s evidence carefully before approving.',
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ClaimerHeaderCard extends StatelessWidget {
  final String name;
  const _ClaimerHeaderCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(PhosphorIconsRegular.user,
                color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claimed by',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.statusPending.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: AppColors.statusPending.withValues(alpha: 0.6)),
            ),
            child: const Text(
              'PENDING',
              style: TextStyle(
                color: AppColors.statusPending,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProofImageGrid extends StatelessWidget {
  final List<String> urls;
  final void Function(String url) onTap;

  const _ProofImageGrid({required this.urls, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: urls.map((url) {
        return GestureDetector(
          onTap: () => onTap(url),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ThemeAwareShimmer(                    child: Container(
                        width: 100, height: 100, color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image,
                        color: Colors.grey, size: 28),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(PhosphorIconsRegular.arrowsOut,
                      color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.warning,
              color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Colors.orange.shade800, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonPanel extends StatelessWidget {
  final String heading;
  final ItemModel item;
  final Color accent;
  final void Function(String url) onImageTap;

  const _ComparisonPanel({
    required this.heading,
    required this.item,
    required this.accent,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            color: accent.withValues(alpha: 0.08),
            child: Text(
              heading,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: accent,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ),
          GestureDetector(
            onTap: item.imageUrl.isNotEmpty
                ? () => onImageTap(item.imageUrl)
                : null,
            child: Stack(
              children: [
                item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ThemeAwareShimmer(                          child: Container(height: 130, color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
                if (item.imageUrl.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(PhosphorIconsRegular.arrowsOut,
                          color: Colors.white, size: 11),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _pill(context, 'Type', item.postType),
                const SizedBox(height: 4),
                _pill(context, 'Category', item.category),
                const SizedBox(height: 4),
                _pill(context, 'Status', item.status),
                const SizedBox(height: 10),
                Text(
                  item.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 130,
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined,
          color: Colors.grey.shade400, size: 32),
    );
  }
}

class _ComparisonPlaceholder extends StatelessWidget {
  const _ComparisonPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(PhosphorIconsRegular.fileDashed,
              size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'No linked LOST report',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onReject;
  final VoidCallback onApprove;

  const _ActionBar({required this.onReject, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onReject,
              icon: Icon(PhosphorIconsRegular.x,
                  size: 16, color: Colors.red.shade700),
              label: Text('Reject',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.red.shade700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(PhosphorIconsRegular.checkCircle,
                  size: 18, color: Colors.white),
              label: const Text('Approve',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusResolved,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
