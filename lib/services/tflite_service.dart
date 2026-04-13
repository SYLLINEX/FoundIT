import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  Interpreter? _interpreter;
  List<String>? _labels;

  // ─────────────────────────────────────────────────────────────────────────
  // MODEL CONFIGURATION
  // ─────────────────────────────────────────────────────────────────────────
  // ✅ Phase 3 complete — now using fine-tuned MobileNetV3 (93% val accuracy)
  static const String _modelPath = 'assets/foundit_mobilenetv3.tflite';
  static const String _labelsPath = 'assets/foundit_labels.txt';
  static const int _inputSize = 224;
  static const double _confidenceThreshold = 0.55;

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset(_modelPath);
    final labelData = await rootBundle.loadString(_labelsPath);
    _labels = labelData
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Classifies an image and returns the top category name.
  /// Returns "Unknown Item" if confidence is below threshold.
  Future<String> classifyItem(File imageFile) async {
    if (_interpreter == null || _labels == null) await initialize();

    final results = await _runInference(imageFile);
    if (results.isEmpty) return 'Unknown Item';

    final best = results.first;
    if (best.value >= _confidenceThreshold) {
      return _resolveLabel(best.key) ?? 'Unknown Item';
    }
    return 'Unknown Item';
  }

  /// Returns the raw 10-dimensional probability vector from the model output.
  /// This score vector is stored in Firestore and used for cosine similarity
  /// comparison between reports — enabling true visual matching.
  /// Returns an empty list if inference fails.
  Future<List<double>> getScoreVector(File imageFile) async {
    if (_interpreter == null || _labels == null) await initialize();

    final input = await _preprocessImage(imageFile);
    if (input == null) return [];

    final outputTensor = _interpreter!.getOutputTensor(0);
    final outLength = outputTensor.shape.length > 1
        ? outputTensor.shape[1]
        : _labels!.length;

    final output = List.generate(1, (_) => List.filled(outLength, 0.0));
    _interpreter!.run(input, output);

    return output[0]
        .take(_labels!.length)
        .map((e) => (e as num).toDouble())
        .toList();
  }

  /// Returns a list of category names whose confidence meets the threshold.
  /// Useful for populating multiple AI-suggested tags on an item report.
  Future<List<String>> getTopLabels(File imageFile, {int count = 5}) async {
    if (_interpreter == null || _labels == null) await initialize();

    final results = await _runInference(imageFile);

    // Debug logging
    print('─── TFLite Top $count Predictions ─────────────────');
    for (final entry in results.take(count)) {
      print('  ${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%');
    }
    print('────────────────────────────────────────────────────');

    return results
        .where((e) => e.value >= _confidenceThreshold)
        .take(count)
        .map((e) => _resolveLabel(e.key))
        .where((label) => label != null)
        .cast<String>()
        .toSet() // deduplicate
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Runs the model on the image and returns results sorted by confidence.
  Future<List<MapEntry<String, double>>> _runInference(File imageFile) async {
    final input = await _preprocessImage(imageFile);
    if (input == null) return [];

    final outputTensor = _interpreter!.getOutputTensor(0);
    final outLength = outputTensor.shape.length > 1
        ? outputTensor.shape[1]
        : _labels!.length;

    final output = List.generate(1, (_) => List.filled(outLength, 0.0));
    _interpreter!.run(input, output);

    final scores = output[0];
    final labelCount = _labels!.length;

    final entries = List.generate(
      outLength < labelCount ? outLength : labelCount,
      (i) => MapEntry(_labels![i], (scores[i] as num).toDouble()),
    );

    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Center-crops and resizes the image, then passes raw [0–255] float values.
  /// NOTE: The TFLite model was exported with include_preprocessing=True, so
  /// normalization to [-1, 1] is handled internally — do NOT pre-normalize here.
  Future<List<List<List<List<double>>>>?> _preprocessImage(
      File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;

    // Center crop to square
    final size = decoded.width < decoded.height ? decoded.width : decoded.height;
    final x = (decoded.width - size) ~/ 2;
    final y = (decoded.height - size) ~/ 2;
    final cropped =
        img.copyCrop(decoded, x: x, y: y, width: size, height: size);
    final resized =
        img.copyResize(cropped, width: _inputSize, height: _inputSize);

    // Pass raw pixel values [0, 255] — model normalizes internally
    return List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (row) => List.generate(
          _inputSize,
          (col) {
            final pixel = resized.getPixel(col, row);
            return [
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LABEL RESOLUTION
  // Fine-tuned model already outputs our 10 domain-specific display labels
  // directly — no mapping needed.
  // ─────────────────────────────────────────────────────────────────────────

  String? _resolveLabel(String rawLabel) {
    final label = rawLabel.trim();
    return label.isNotEmpty ? label : null;
  }
}
