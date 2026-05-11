import 'package:flutter/material.dart';
import 'feature_tour_step.dart';
import 'feature_tour_overlay.dart';

/// Manages the lifecycle of the feature tour.
/// Usage:
///   1. Create a [FeatureTourController] and keep it alive in your StatefulWidget.
///   2. Call [start] from `addPostFrameCallback` with your list of steps.
///   3. The controller drives the overlay forward with [_next] / [_dismiss].
class FeatureTourController {
  final BuildContext _context;
  List<FeatureTourStep> _steps = [];
  int _currentIndex = 0;
  OverlayEntry? _overlayEntry;
  VoidCallback? onCompleted;

  FeatureTourController(this._context);

  int get currentIndex => _currentIndex;
  int get totalSteps => _steps.length;
  bool get isRunning => _overlayEntry != null;

  void start(List<FeatureTourStep> steps, {VoidCallback? onCompleted}) {
    if (steps.isEmpty) return;
    _steps = steps;
    _currentIndex = 0;
    this.onCompleted = onCompleted;
    _showStep();
  }

  void _next() {
    _currentIndex++;
    if (_currentIndex < _steps.length) {
      _removeOverlay();
      _showStep();
    } else {
      _dismiss(completed: true);
    }
  }

  void _dismiss({bool completed = false}) {
    _removeOverlay();
    if (completed || onCompleted != null) {
      onCompleted?.call();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showStep() {
    final step = _steps[_currentIndex];

    _overlayEntry = OverlayEntry(
      builder: (context) => FeatureTourOverlay(
        step: step,
        currentStep: _currentIndex + 1,
        totalSteps: _steps.length,
        onNext: _next,
        onSkip: () => _dismiss(completed: true),
      ),
    );

    Overlay.of(_context).insert(_overlayEntry!);
  }

  void dispose() {
    _removeOverlay();
  }
}
