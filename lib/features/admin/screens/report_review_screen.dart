import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/item_model.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/app_confirmation_dialog.dart';

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

class ReportReviewScreen extends StatefulWidget {
  final ItemModel targetItem;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  const ReportReviewScreen({
    super.key,
    required this.targetItem,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  // Removed unused notification service unless you plan to use it here
  bool _isProcessing = false;

  void _openReportMap(ItemModel item) {
    if (item.location == null) return;
    
    final latLng = LatLng(item.location!.latitude, item.location!.longitude);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Reported Location'),
            backgroundColor: AppColors.adminVerificationInk,
            foregroundColor: Colors.white,
          ),
          body: GoogleMap(
            initialCameraPosition: CameraPosition(target: latLng, zoom: 16),
            markers: {
              Marker(
                markerId: MarkerId(item.itemId),
                position: latLng,
                infoWindow: InfoWindow(
                  title: item.title,
                  snippet: item.specificLocation ?? item.locationName,
                ),
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.adminVerificationSurfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.imageBroken,
            size: 32,
            color: Colors.grey,
          ),
          SizedBox(height: 8),
          Text(
            'No image available',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.adminVerificationMutedInk,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.adminVerificationInk,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  Future<void> _handleApprove() async {
    final confirmed = await showAppConfirmationDialog<bool>(
      context: context,
      title: 'Approve Report?',
      message: 'This report will be visible to users.',
      confirmText: 'Approve',
      cancelText: 'Cancel',
      confirmColor: AppColors.statusOpen,
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await widget.onApprove();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        // Log error or show snackbar
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await showAppConfirmationDialog<bool>(
      context: context,
      title: 'Reject Report?',
      message: 'This report will be removed from review.',
      confirmText: 'Reject',
      cancelText: 'Cancel',
      confirmColor: AppColors.error,
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await widget.onReject();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        // Log error
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.targetItem;
    final isLost = item.postType.toLowerCase() == 'lost';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(isLost ? 'Review Lost Report' : 'Review Found Report'),
        backgroundColor: AppColors.adminVerificationInk,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      // Use Column for body with Expanded for ScrollView and a fixed BottomBar
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.adminVerificationInk,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isLost
                                    ? const Color(0xFFEF4444).withOpacity(0.1)
                                    : const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isLost ? 'LOST' : 'FOUND',
                                style: TextStyle(
                                  color: isLost
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(item.timestamp),
                          style: const TextStyle(
                            color: AppColors.adminVerificationMutedInk,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hero Image
                  if (item.imageUrl.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FullScreenImagePage(
                              imageUrl: item.imageUrl,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (_, __, ___) => _buildImagePlaceholder(),
                        ),
                      ),
                    )
                  else
                    _buildImagePlaceholder(),
                  const SizedBox(height: 24),

                  // Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.adminVerificationInk,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _detailRow('Category', item.category),
                        _detailRow('Status', item.status),
                        _detailRow(
                          'Location',
                          item.specificLocation?.isNotEmpty == true
                              ? '${item.specificLocation} (${item.locationName})'
                              : item.locationName,
                        ),
                        const SizedBox(height: 12),
                        const Divider(
                            color: AppColors.adminVerificationBorderSoft),
                        const SizedBox(height: 16),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.adminVerificationMutedInk,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: AppColors.adminVerificationInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Action Bar (Fixed outside scroll view)
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: AppColors.adminVerificationBorderSoft),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (item.location != null) ...[
                  OutlinedButton(
                    onPressed: () => _openReportMap(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.adminVerificationInk,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      side: const BorderSide(
                        color: AppColors.adminVerificationBorderSoft,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        const Icon(PhosphorIconsRegular.mapTrifold, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _handleReject,
                    icon: const Icon(PhosphorIconsRegular.xCircle, size: 18),
                    label: const Text('Reject',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handleApprove,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(PhosphorIconsRegular.checkCircle, size: 18),
                    label: Text(
                      _isProcessing ? 'Processing' : 'Approve',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusOpen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}