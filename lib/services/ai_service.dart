import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/item_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Typed breakdown of each sub-score that makes up the composite similarity.
// ─────────────────────────────────────────────────────────────────────────────
class SimilarityBreakdown {
  /// Cosine similarity of the 10-dim AI score vectors (0–100)
  final double visual;

  /// Jaccard similarity of the top AI labels (0–100)
  final double labels;

  /// Token-level Jaccard overlap of title + description text (0–100)
  final double description;

  /// Time proximity between lost date and found date (0–100)
  final double time;

  /// Geographic proximity (0–100, 0 if no GPS data)
  final double location;

  /// Category exact match — 100 if same, 0 if different (gated at comparison level)
  final double category;

  /// Weighted composite score (mirrors AIService.compareLostReportToClaim)
  final double overall;

  const SimilarityBreakdown({
    required this.visual,
    required this.labels,
    required this.description,
    required this.time,
    required this.location,
    required this.category,
    required this.overall,
  });
}

class AIService {
  static const double lowSimilarityThreshold = 60.0;

  // ─────────────────────────────────────────────────────────────────────────
  // MATCHING WEIGHTS
  // ─────────────────────────────────────────────────────────────────────────
  static const double visualWeight   = 0.50; // cosine similarity of score vectors
  static const double labelsWeight   = 0.10; // Jaccard similarity of top labels
  static const double textWeight     = 0.15; // title + description token overlap
  static const double timeWeight     = 0.10; // time proximity
  static const double locationWeight = 0.10; // geographic proximity
  static const double categoryWeight = 0.05; // exact user-selected category match

  static const double maxDistanceForScoreMeters = 5000.0;
  static const int maxTimeDiffHours = 720; // 30 days decay

  // ─────────────────────────────────────────────────────────────────────────
  // PRIMARY COMPARISON: Lost Report vs Claim / Found Report
  // ─────────────────────────────────────────────────────────────────────────

  double compareLostReportToClaim({
    required ItemModel linkedLostReport,
    required ItemModel claimTargetItem,
    required String claimDescription,
  }) {
    // 1. HARD GATE: Category Match
    if (linkedLostReport.category.toLowerCase() != claimTargetItem.category.toLowerCase()) {
      return 0.0;
    }

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
    final categoryScore = 100.0; // If they passed the gate, they match 100% on category
    
    final locationScore = _locationSimilarity(linkedLostReport, claimTargetItem);
    final timeScore = _timeSimilarity(linkedLostReport, claimTargetItem);

    final weighted =
        (visualScore   * visualWeight) +
        (labelsScore   * labelsWeight) +
        (textScore     * textWeight) +
        (categoryScore * categoryWeight) +
        (locationScore * locationWeight) +
        (timeScore     * timeWeight);

    return weighted.clamp(0.0, 100.0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BREAKDOWN: Returns each sub-score individually for admin analytics UI.
  // Call this with the same arguments as compareLostReportToClaim().
  // ─────────────────────────────────────────────────────────────────────────

  SimilarityBreakdown getSimilarityBreakdown({
    required ItemModel linkedLostReport,
    required ItemModel claimTargetItem,
    required String claimDescription,
  }) {
    final categoryMatch =
        linkedLostReport.category.toLowerCase() ==
        claimTargetItem.category.toLowerCase();

    final visual = categoryMatch
        ? _cosineSimilarity(
            linkedLostReport.aiScoreVector, claimTargetItem.aiScoreVector)
        : 0.0;
    final labels = categoryMatch
        ? _labelsSimilarity(
            linkedLostReport.aiLabels, claimTargetItem.aiLabels)
        : 0.0;
    final description = categoryMatch
        ? _textSimilarity(
            '${linkedLostReport.title} ${linkedLostReport.description}',
            '${claimTargetItem.title} ${claimTargetItem.description} $claimDescription')
        : 0.0;
    final categoryScore = categoryMatch ? 100.0 : 0.0;
    final location =
        categoryMatch ? _locationSimilarity(linkedLostReport, claimTargetItem) : 0.0;
    final time =
        categoryMatch ? _timeSimilarity(linkedLostReport, claimTargetItem) : 0.0;

    final overall = categoryMatch
        ? ((visual * visualWeight) +
               (labels * labelsWeight) +
               (description * textWeight) +
               (categoryScore * categoryWeight) +
               (location * locationWeight) +
               (time * timeWeight))
            .clamp(0.0, 100.0)
        : 0.0;

    return SimilarityBreakdown(
      visual: visual,
      labels: labels,
      description: description,
      time: time,
      location: location,
      category: categoryScore,
      overall: overall,
    );
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

  // ─────────────────────────────────────────────────────────────────────────
  // TIME SIMILARITY
  // ─────────────────────────────────────────────────────────────────────────

  double _timeSimilarity(ItemModel lost, ItemModel found) {
    // Use explicit eventDate (user selected) if available, otherwise fallback to timestamp
    final lostTime = lost.eventDate ?? lost.timestamp;
    final foundTime = found.eventDate ?? found.timestamp;
    
    // Usually, a lost item happens first, then it is found.
    final difference = foundTime.difference(lostTime);
    
    // If the item was found significantly BEFORE it was lost, this is a strong negative indicator.
    // We allow a small 1-day grace period (24 hrs) in case people entered the date slightly wrong.
    if (difference.inHours < -24) {
      return 0.0;
    }

    final absHours = difference.inHours.abs();
    
    if (absHours > maxTimeDiffHours) {
      return 0.0;
    }

    // Linear decay from 100 to 0 over maxTimeDiffHours (30 days by default)
    final double score = 100.0 - ((absHours / maxTimeDiffHours) * 100.0);
    return score.clamp(0.0, 100.0);
  }
}
