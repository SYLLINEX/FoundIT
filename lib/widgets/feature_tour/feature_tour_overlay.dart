import 'dart:math';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'feature_tour_step.dart';

/// Full-screen overlay that:
///   • Dims everything except the [step.targetKey] widget (spotlight effect).
///   • Shows a tooltip card with title, description, step counter, Next / Skip.
class FeatureTourOverlay extends StatefulWidget {
  final FeatureTourStep step;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const FeatureTourOverlay({
    super.key,
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<FeatureTourOverlay> createState() => _FeatureTourOverlayState();
}

class _FeatureTourOverlayState extends State<FeatureTourOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  Rect _targetRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _resolveTargetRect();
    _controller.forward();

    // Gentle pulse loop after entrance
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  void _resolveTargetRect() {
    final key = widget.step.targetKey;
    final renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      _targetRect = offset & renderBox.size;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = 12.0;
    final spotlightRect = _targetRect.inflate(padding);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // ── Dimmed backdrop with spotlight cutout ──────────────────────
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, _) {
                final scale = _pulseAnim.value;
                final scaledRect = Rect.fromCenter(
                  center: spotlightRect.center,
                  width: spotlightRect.width * scale,
                  height: spotlightRect.height * scale,
                );
                return CustomPaint(
                  size: size,
                  painter: _SpotlightPainter(
                    spotlightRect: scaledRect,
                    overlayColor: Colors.black.withOpacity(0.72),
                  ),
                );
              },
            ),

            // ── Tap anywhere on dim area to advance ───────────────────────
            GestureDetector(
              onTap: widget.onNext,
              behavior: HitTestBehavior.translucent,
            ),

            // ── Tooltip card ──────────────────────────────────────────────
            Positioned(
              top: _tooltipTop(size, spotlightRect),
              left: 20,
              right: 20,
              child: _buildTooltipCard(context),
            ),
          ],
        ),
      ),
    );
  }

  double _tooltipTop(Size screen, Rect spotlight) {
    const cardHeight = 180.0;
    const spacing = 18.0;

    switch (widget.step.tooltipPosition) {
      case TooltipPosition.above:
        final above = spotlight.top - cardHeight - spacing;
        return above > 0 ? above : spotlight.bottom + spacing;
      case TooltipPosition.below:
        final below = spotlight.bottom + spacing;
        return below + cardHeight < screen.height
            ? below
            : spotlight.top - cardHeight - spacing;
      default:
        final below = spotlight.bottom + spacing;
        return below + cardHeight < screen.height
            ? below
            : max(20, spotlight.top - cardHeight - spacing);
    }
  }

  Widget _buildTooltipCard(BuildContext context) {
    final isLast = widget.currentStep == widget.totalSteps;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2C40),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Step counter ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C72E5).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step ${widget.currentStep} of ${widget.totalSteps}',
                  style: const TextStyle(
                    color: Color(0xFFB3AEF5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Dot progress indicators
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: List.generate(widget.totalSteps, (i) {
                    final active = i < widget.currentStep;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 3,
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF7C72E5)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Title ────────────────────────────────────────────────────────
          Text(
            widget.step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 8),

          // ── Description ──────────────────────────────────────────────────
          Text(
            widget.step.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          // ── Buttons ──────────────────────────────────────────────────────
          Row(
            children: [
              // Skip (only shown when not last step)
              if (!isLast)
                TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Skip tour'),
                ),
              const Spacer(),
              // Next / Done
              ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C72E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? 'Done!' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isLast
                          ? PhosphorIconsBold.checkCircle
                          : PhosphorIconsBold.caretRight,
                      size: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── CustomPainter: cuts a rounded spotlight out of the dark overlay ──────────
class _SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;
  final Color overlayColor;

  _SpotlightPainter({
    required this.spotlightRect,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final overlayPath = Path()..addRect(fullRect);

    // Cut out a rounded rectangle for the spotlight
    const radius = Radius.circular(14);
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(spotlightRect, radius));

    final combined =
        Path.combine(PathOperation.difference, overlayPath, cutout);

    canvas.drawPath(combined, Paint()..color = overlayColor);

    // Highlight border around spotlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, radius),
      Paint()
        ..color = const Color(0xFF7C72E5).withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotlightRect != spotlightRect;
}
