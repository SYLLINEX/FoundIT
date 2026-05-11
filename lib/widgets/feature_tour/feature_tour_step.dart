import 'package:flutter/material.dart';

/// Tooltip placement relative to the highlighted widget.
enum TooltipPosition { above, below, left, right }

/// A single step in the feature tour.
class FeatureTourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final TooltipPosition tooltipPosition;

  const FeatureTourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.tooltipPosition = TooltipPosition.above,
  });
}
