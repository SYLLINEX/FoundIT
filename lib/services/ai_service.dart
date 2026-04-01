import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/item_model.dart';

class AIService {
  static const double lowSimilarityThreshold = 60.0;

  // ─────────────────────────────────────────────────────────────────────────
  // MATCHING WEIGHTS
  // Visual score vector comparison carries the highest weight since our
  // fine-tuned model produces a reliable 10-dim probability distribution.
  // ─────────────────────────────────────────────────────────────────────────
  static const double visualWeight   = 0.35; // cosine similarity of score vectors
  static const double labelsWeight   = 0.30; // Jaccard similarity of top labels
  static const double textWeight     = 0.20; // title + description token overlap
  static const double categoryWeight = 0.10; // exact user-selected category match
  static const double locationWeight = 0.05; // geographic proximity

  static const double maxDistanceForScoreMeters = 5000.0;

  // ─────────────────────────────────────────────────────────────────────────
  // PRIMARY COMPARISON: Lost Report vs Claim / Found Report
  // ─────────────────────────────────────────────────────────────────────────

  double compareLostReportToClaim({
    required ItemModel linkedLostReport,
    required ItemModel claimTargetItem,
    required String claimDescription,
  }) {
    final visualScore = _cosineSimilarity(
      linkedLostReport.aiScoreVector,
      claimTargetItem.aiScoreVector,
    );
    final labelsScore = _labelsSimilarity(
      linkedLostReport.aiLabels,
      claimTargetItem.aiLabels,
    );
    final textScore = _textSimilarity(
      '${linkedLostReport.title} ${linkedLostReport.description}',
      '${claimTargetItem.title} ${claimTargetItem.description} $claimDescription',
    );
    final categoryScore =
        linkedLostReport.category.toLowerCase() ==
            claimTargetItem.category.toLowerCase()
        ? 100.0
        : 0.0;
    final locationScore = _locationSimilarity(linkedLostReport, claimTargetItem);

    final weighted =
        (visualScore   * visualWeight) +
        (labelsScore   * labelsWeight) +
        (textScore     * textWeight) +
        (categoryScore * categoryWeight) +
        (locationScore * locationWeight);

    return weighted.clamp(0.0, 100.0);
  }

  bool isLowSimilarity(double? score) {
    if (score == null) return false;
    return score < lowSimilarityThreshold;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VISUAL SCORE VECTOR SIMILARITY
  // Cosine similarity of the 10-dim softmax probability vectors.
  // Two images of the same item type will have similar distributions
  // (e.g., backpack: [0.05, 0.85, 0.02, ...] vs [0.03, 0.88, 0.04, ...]).
  // Returns 0–100.
  // ─────────────────────────────────────────────────────────────────────────

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double magnitudeA = 0.0;
    double magnitudeB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      magnitudeA += a[i] * a[i];
      magnitudeB += b[i] * b[i];
    }

    magnitudeA = sqrt(magnitudeA);
    magnitudeB = sqrt(magnitudeB);

    if (magnitudeA == 0.0 || magnitudeB == 0.0) return 0.0;
    return ((dotProduct / (magnitudeA * magnitudeB)) * 100).clamp(0.0, 100.0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LABEL SIMILARITY (Jaccard)
  // ─────────────────────────────────────────────────────────────────────────

  double _labelsSimilarity(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 0.0;
    final lowerA = a.map((e) => e.toLowerCase().trim()).toSet();
    final lowerB = b.map((e) => e.toLowerCase().trim()).toSet();
    if (lowerA.isEmpty || lowerB.isEmpty) return 0.0;

    final intersection = lowerA.intersection(lowerB).length;
    final union = lowerA.union(lowerB).length;
    if (union == 0) return 0.0;

    return (intersection / union) * 100;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT SIMILARITY (Token Jaccard)
  // ─────────────────────────────────────────────────────────────────────────

  double _textSimilarity(String left, String right) {
    final leftTokens = _tokenize(left);
    final rightTokens = _tokenize(right);
    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0.0;

    final intersection = leftTokens.intersection(rightTokens).length;
    final union = leftTokens.union(rightTokens).length;
    if (union == 0) return 0.0;

    return (intersection / union) * 100;
  }

  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 2)
        .toSet();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCATION SIMILARITY
  // ─────────────────────────────────────────────────────────────────────────

  double _locationSimilarity(ItemModel a, ItemModel b) {
    if (a.location == null || b.location == null) return 0.0;

    final distanceMeters = Geolocator.distanceBetween(
      a.location!.latitude,
      a.location!.longitude,
      b.location!.latitude,
      b.location!.longitude,
    );

    final score = 100 - ((distanceMeters / maxDistanceForScoreMeters) * 100);
    return score.clamp(0.0, 100.0);
  }
}
