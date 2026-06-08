import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../core/theme/app_colors.dart';
import 'theme_aware_shimmer.dart';

/// A swipeable image carousel backed by CachedNetworkImage.
/// Falls back to a single image view when [imageUrls] has exactly 1 element.
class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final BoxFit fit;

  const ImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = double.infinity,
    this.fit = BoxFit.cover,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;

    if (urls.isEmpty) {
      return _buildPlaceholder();
    }

    if (urls.length == 1) {
      return _buildImage(urls.first);
    }

    return Stack(
      children: [
        // ── Page View ───────────────────────────────────────────────────────
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) => _buildImage(urls[index]),
          ),
        ),

        // ── Dot Indicator ───────────────────────────────────────────────────
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: isActive ? 20 : 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
        ),

        // ── Image counter badge (top-right) ─────────────────────────────────
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentPage + 1} / ${urls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      width: double.infinity,
      height: widget.height,
      placeholder: (context, _) =>
          ThemeAwareShimmer(child: Container(color: Colors.white)),
      errorWidget: (context, url, err) => Container(
        color: AppColors.mist,
        child: const Icon(
          PhosphorIconsRegular.imageBroken,
          size: 50,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.mist,
      child: const Center(
        child: Icon(
          PhosphorIconsRegular.image,
          size: 60,
          color: Colors.grey,
        ),
      ),
    );
  }
}
