import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'theme_aware_shimmer.dart';

class ItemCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String status;
  final String location;
  final String timeText;
  final String reporterName;
  final double? distanceKm;
  final VoidCallback? onTap;

  const ItemCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.status,
    required this.location,
    required this.timeText,
    this.reporterName = 'Unknown',
    this.distanceKm,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final onCard = Theme.of(context).colorScheme.onSurface;
    final subtleColor = onCard.withOpacity(0.55);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image / Tag
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => ThemeAwareShimmer(                    child: Container(color: cardColor),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: Icon(
                      PhosphorIconsRegular.imageBroken,
                      color: subtleColor,
                    ),
                  ),
                ),
              ),
            ),

            // Details
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: onCard,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status.toUpperCase() == 'RESERVED'
                                ? Colors.amber.shade700
                                : (status.toUpperCase() == 'LOST'
                                    ? AppColors.statusLost
                                    : AppColors.statusFound),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(PhosphorIconsRegular.mapPin,
                            size: 14, color: subtleColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location,
                            style: TextStyle(color: subtleColor, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceKm != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: onCard.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              distanceKm! < 1
                                  ? '${(distanceKm! * 1000).round()} m'
                                  : '${distanceKm!.toStringAsFixed(1)} km',
                              style: TextStyle(
                                color: onCard,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Icon(PhosphorIconsRegular.calendarBlank,
                            size: 14, color: subtleColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            timeText,
                            style: TextStyle(color: subtleColor, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(PhosphorIconsRegular.user,
                            size: 14, color: subtleColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Uploaded by $reporterName',
                            style: TextStyle(color: subtleColor, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
