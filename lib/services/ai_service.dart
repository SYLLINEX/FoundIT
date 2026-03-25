import 'package:geolocator/geolocator.dart';

import '../models/item_model.dart';

class AIService {
  static const double lowSimilarityThreshold = 60.0;

  static const double labelsWeight = 0.45;
  static const double textWeight = 0.30;
  static const double categoryWeight = 0.15;
  static const double locationWeight = 0.10;
  static const double maxDistanceForScoreMeters = 5000.0;

  double compareLostReportToClaim({
    required ItemModel linkedLostReport,
    required ItemModel claimTargetItem,
    required String claimDescription,
  }) {
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
    final locationScore = _locationSimilarity(
      linkedLostReport,
      claimTargetItem,
    );

    final weighted =
        (labelsScore * labelsWeight) +
        (textScore * textWeight) +
        (categoryScore * categoryWeight) +
        (locationScore * locationWeight);

    return weighted.clamp(0.0, 100.0);
  }

  bool isLowSimilarity(double? score) {
    if (score == null) return false;
    return score < lowSimilarityThreshold;
  }

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
