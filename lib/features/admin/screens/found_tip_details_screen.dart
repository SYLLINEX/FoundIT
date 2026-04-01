import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/claim_model.dart';
import '../../../models/item_model.dart';
import '../../../services/ai_service.dart';

class FoundTipDetailsScreen extends StatefulWidget {
  final ItemModel targetItem;
  final ClaimModel claim;
  final String claimerName;
  final Future<void> Function(ClaimModel) onApprove;
  final Future<void> Function(ClaimModel) onReject;

  const FoundTipDetailsScreen({
    super.key,
    required this.targetItem,
    required this.claim,
    required this.claimerName,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<FoundTipDetailsScreen> createState() => _FoundTipDetailsScreenState();
}

class _FoundTipDetailsScreenState extends State<FoundTipDetailsScreen> {
  bool _isProcessing = false;

  Future<void> _handleAction(bool isApprove) async {
    setState(() => _isProcessing = true);
    try {
      if (isApprove) {
        await widget.onApprove(widget.claim);
      } else {
        await widget.onReject(widget.claim);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          'Review Found Tip',
          style: TextStyle(
            color: AppColors.nightfall,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.nightfall),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            _buildInfoCard(
              title: 'Reporter',
              value: widget.claimerName,
              icon: PhosphorIconsRegular.user,
            ),
            const SizedBox(height: 16),
            
            // AI Similarity Score
            if (widget.claim.similarityScore != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (widget.claim.similarityScore! < AIService.lowSimilarityThreshold)
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (widget.claim.similarityScore! < AIService.lowSimilarityThreshold)
                        ? Colors.orange.shade300
                        : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (widget.claim.similarityScore! < AIService.lowSimilarityThreshold)
                          ? PhosphorIconsRegular.warningCircle
                          : PhosphorIconsRegular.checkCircle,
                      color: (widget.claim.similarityScore! < AIService.lowSimilarityThreshold)
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI Visual Match: ${widget.claim.similarityScore!.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: (widget.claim.similarityScore! < AIService.lowSimilarityThreshold)
                            ? Colors.orange.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text(
              'Proof Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.nightfall),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                widget.claim.proofDesc,
                style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Comparison',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.nightfall),
            ),
            const SizedBox(height: 16),

            // Finder's Submitted Photo
            _buildImageCard(
              heading: "Finder's Submitted Photo",
              imageUrl: (widget.claim.proofImageUrls != null && widget.claim.proofImageUrls!.isNotEmpty)
                  ? widget.claim.proofImageUrls!.first
                  : '',
              accent: Colors.blue,
              fallbackText: 'No photo submitted',
            ),
            const SizedBox(height: 24),

            // Original LOST Report
            _buildItemCard(
              heading: 'Original LOST Report',
              item: widget.targetItem,
              accent: Colors.red,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing ? null : () => _handleAction(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _handleAction(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusFound,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Approve Tip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.mist,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.nightfall, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.nightfall)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard({required String heading, required String imageUrl, required Color accent, required String fallbackText}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              heading,
              style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white, height: 240),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: double.infinity,
                  height: 240,
                  alignment: Alignment.center,
                  color: Colors.grey.shade100,
                  child: const Icon(PhosphorIconsRegular.imageBroken, color: Colors.grey, size: 32),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Text(fallbackText, style: TextStyle(color: Colors.grey.shade500)),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard({required String heading, required ItemModel item, required Color accent}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              heading,
              style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          if (item.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white, height: 240),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.nightfall),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(item.category),
              _buildPill(item.status),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}
