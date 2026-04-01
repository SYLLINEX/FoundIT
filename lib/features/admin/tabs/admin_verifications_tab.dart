import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/item_model.dart';
import '../../../models/claim_model.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/found_it_loading_indicator.dart';
import '../../../services/ai_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../widgets/app_confirmation_dialog.dart';
import '../widgets/admin_header.dart';
import '../screens/found_tip_details_screen.dart';
import '../../notifications/notifications_screen.dart';
import '../../../widgets/expandable_filter_fab.dart';
import '../../../widgets/empty_state_view.dart';
class AdminVerificationsTab extends StatefulWidget {
  const AdminVerificationsTab({super.key});

  @override
  State<AdminVerificationsTab> createState() => _AdminVerificationsTabState();
}

class _AdminVerificationsTabState extends State<AdminVerificationsTab> {
  final List<String> _categories = const ['All', 'Reports', 'Claims'];
  int _selectedCategoryIndex = 0;
  String _selectedFilter = 'All'; // 'All', 'Reports', or 'Claims'
  String _searchQuery = '';
  final NotificationService _notificationService = NotificationService();

  String get _reportsSectionTitle {
    if (_selectedFilter == 'Reports') return 'Missing Reports';
    return 'All Reports';
  }

  String get _claimsSectionTitle => 'Claim Reports';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AdminHeader(
          title: 'Verifications',
          onNotificationTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
        ),
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // List Area
        Expanded(child: _buildAllList()),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: ExpandableFilterFab(
          categories: _categories,
          selectedCategoryIndex: _selectedCategoryIndex,
          onCategorySelected: (index) {
            setState(() {
              _selectedCategoryIndex = index;
              _selectedFilter = _categories[index];
            });
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildReportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: FoundItLoadingIndicator());
        }

        final pendingDocs = (snapshot.data?.docs ?? []).where((doc) {
          final status =
              (doc.data() as Map<String, dynamic>)['status']
                  ?.toString()
                  .toLowerCase() ??
              '';
          return status == 'pending for approval' || status == 'pending';
        }).toList();

        if (pendingDocs.isEmpty) {
          return const EmptyStateView(
            icon: PhosphorIconsRegular.checkCircle,
            title: 'No pending reports',
            message: 'All reports have been reviewed.',
          );
        }

        final docs = pendingDocs.where((doc) {
          final item = ItemModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          );
          return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = ItemModel.fromMap(
              docs[index].id,
              docs[index].data() as Map<String, dynamic>,
            );
            return _buildReportCard(item);
          },
        );
      },
    );
  }

  Widget _buildClaimsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('claims')
          .where('status', isEqualTo: 'Pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: FoundItLoadingIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateView(
            icon: PhosphorIconsRegular.checkCircle,
            title: 'No pending claims',
            message: 'All claims have been reviewed.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            return _buildClaimCardFromDoc(snapshot.data!.docs[index]);
          },
        );
      },
    );
  }

  Widget _buildAllList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (context, reportsSnapshot) {
        if (reportsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: FoundItLoadingIndicator());
        }

        final pendingReportDocs = (reportsSnapshot.data?.docs ?? []).where((
          doc,
        ) {
          final status =
              (doc.data() as Map<String, dynamic>)['status']
                  ?.toString()
                  .toLowerCase() ??
              '';
          return status == 'pending for approval' || status == 'pending';
        }).toList();

        final filteredReports = pendingReportDocs.where((doc) {
          final item = ItemModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          );
          return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('claims')
              .where('status', isEqualTo: 'Pending')
              .snapshots(),
          builder: (context, claimsSnapshot) {
            if (claimsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: FoundItLoadingIndicator());
            }

            final showReports = _selectedFilter != 'Claims';
            final showClaims = _selectedFilter != 'Reports';
            final claimDocs = claimsSnapshot.data?.docs ?? [];
            final noReports = !showReports || filteredReports.isEmpty;
            final noClaims = !showClaims || claimDocs.isEmpty;

            if (noReports && noClaims) {
              if (_selectedFilter == 'Reports') {
                return const EmptyStateView(
                  icon: PhosphorIconsRegular.checkCircle,
                  title: 'No pending reports',
                  message: 'All reports have been reviewed.',
                );
              }
              if (_selectedFilter == 'Claims') {
                return const EmptyStateView(
                  icon: PhosphorIconsRegular.checkCircle,
                  title: 'No pending claims',
                  message: 'All claims have been reviewed.',
                );
              }
              return const EmptyStateView(
                icon: PhosphorIconsRegular.checkCircle,
                title: 'All caught up!',
                message: 'There are no pending reports or claims to review.',
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                if (showReports && filteredReports.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _reportsSectionTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminVerificationInk,
                      ),
                    ),
                  ),
                  ...filteredReports.map((doc) {
                    final item = ItemModel.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    );
                    return _buildReportCard(item);
                  }),
                ],
                if (showReports &&
                    showClaims &&
                    filteredReports.isNotEmpty &&
                    claimDocs.isNotEmpty)
                  const SizedBox(height: 8),
                if (showClaims && claimDocs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _claimsSectionTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminVerificationInk,
                      ),
                    ),
                  ),
                  ...claimDocs.map(_buildClaimCardFromDoc),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildClaimCardFromDoc(QueryDocumentSnapshot<Object?> doc) {
    final claim = ClaimModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>,
    );

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('items')
          .doc(claim.itemId)
          .get(),
      builder: (context, itemSnap) {
        if (!itemSnap.hasData) return const SizedBox();
        final itemData = itemSnap.data!.data();
        if (itemData == null) return const SizedBox();

        final item = ItemModel.fromMap(
          itemSnap.data!.id,
          itemData as Map<String, dynamic>,
        );

        if (_searchQuery.isNotEmpty &&
            !item.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return const SizedBox();
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(claim.claimantId)
              .get(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const SizedBox();
            final userData = userSnap.data!.data();
            final userName =
                (userData as Map<String, dynamic>?)?['username'] ?? 'User';

            return _buildClaimCard(item, claim, userName);
          },
        );
      },
    );
  }

  Widget _buildReportCard(ItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.adminVerificationBorderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Metadata Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.statusPendingSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    color: AppColors.statusPending,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                _formatTime(item.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.adminVerificationInk,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Combined Location & Reporter for minimalism
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.mapPin,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${item.locationName} - By ${item.reporterName ?? "Unknown"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.adminVerificationMutedInk,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4A4A5A),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Secondary Actions (View details / Map)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showReportDetails(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.adminVerificationInk,
                    side: const BorderSide(
                      color: AppColors.adminVerificationBorderSoft,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Details',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (item.location != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openReportMap(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.adminVerificationInk,
                      side: const BorderSide(
                        color: AppColors.adminVerificationBorderSoft,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Map',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              height: 1,
              color: AppColors.adminVerificationBorderSoft,
            ),
          ),

          // Primary Actions (Reject / Approve)
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _confirmRejectReport(item),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _confirmApproveReport(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusOpen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(ItemModel item, ClaimModel claim, String claimerName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.adminVerificationBorderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Metadata Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.statusPendingSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    color: AppColors.statusPending,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                _formatTime(claim.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.adminVerificationInk,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Claimant
          Row(
            children: [
              const Icon(PhosphorIconsRegular.user, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Claimed by $claimerName',
                  style: const TextStyle(
                    color: AppColors.adminVerificationMutedInk,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Proof Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.adminVerificationSurfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Proof provided',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.adminVerificationMutedInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  claim.proofDesc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.adminVerificationInk,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // AI Similarity Link
          if (claim.linkedLostReportId != null &&
              claim.linkedLostReportId!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.link,
                    size: 16,
                    color: Colors.indigo.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linked LOST Report attached',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                  if (claim.similarityScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${claim.similarityScore!.toStringAsFixed(0)}% Match',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color:
                              (claim.similarityScore! <
                                  AIService.lowSimilarityThreshold)
                              ? Colors.orange.shade800
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Review Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showClaimDetails(item, claim, claimerName),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.adminVerificationInk,
                side: const BorderSide(
                  color: AppColors.adminVerificationBorderSoft,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Review Details',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              height: 1,
              color: AppColors.adminVerificationBorderSoft,
            ),
          ),

          // Primary Actions (Reject / Approve)
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _confirmRejectClaim(claim),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _confirmApproveClaim(claim),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusResolved,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmApproveReport(ItemModel item) async {
    final confirmed = await showAppConfirmationDialog<bool>(
      context: context,
      title: 'Approve Report?',
      message: 'This report will be visible to users.',
      confirmText: 'Approve',
      cancelText: 'Cancel',
      confirmColor: AppColors.statusOpen,
    );

    if (confirmed == true) {
      await _approveReport(item);
    }
  }

  Future<void> _confirmRejectReport(ItemModel item) async {
    final confirmed = await showAppConfirmationDialog<bool>(
      context: context,
      title: 'Reject Report?',
      message: 'This report will be removed from review.',
      confirmText: 'Reject',
      cancelText: 'Cancel',
      confirmColor: AppColors.error,
    );

    if (confirmed == true) {
      await _rejectReport(item);
    }
  }

  Future<void> _confirmApproveClaim(ClaimModel claim) async {
    final confirmed = await showAppConfirmationDialog<bool>(
      context: context,
      title: 'Approve Claim?',
      message: 'The item will be reserved for this claimant.',
      confirmText: 'Approve',
      cancelText: 'Cancel',
      confirmColor: AppColors.statusResolved,
    );

    if (confirmed == true) {
      await _approveClaim(claim);
    }
  }

  Future<void> _confirmRejectClaim(ClaimModel claim) async {
    final confirmed = await showAppConfirmationDialog<bool>(
      context: context,
      title: 'Reject Claim?',
      message: 'This claim will be removed from review.',
      confirmText: 'Reject',
      cancelText: 'Cancel',
      confirmColor: AppColors.error,
    );

    if (confirmed == true) {
      await _rejectClaim(claim);
    }
  }

  Future<void> _approveReport(ItemModel item) async {
    await FirebaseFirestore.instance
        .collection('items')
        .doc(item.itemId)
        .update({'status': 'Open'});

    await _notificationService.createNotification(
      userId: item.userId,
      title: 'Report approved',
      body:
          'Your report "${item.title}" is approved and now visible to everyone.',
      type: 'report_approved',
      relatedItemId: item.itemId,
    );

    await _notificationService.notifyNearbyUsersForReport(
      report: item,
      radiusMeters: 500,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report approved and published.')),
      );
    }
  }

  Future<void> _rejectReport(ItemModel item) async {
    await FirebaseFirestore.instance
        .collection('items')
        .doc(item.itemId)
        .update({'status': 'Rejected'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report rejected and removed.')),
      );
    }
  }

  Future<void> _approveClaim(ClaimModel claim) async {
    final claimsRef = FirebaseFirestore.instance.collection('claims');
    await claimsRef.doc(claim.claimId).update({'status': 'Approved'});

    final itemDoc = await FirebaseFirestore.instance
        .collection('items')
        .doc(claim.itemId)
        .get();
    final itemData = itemDoc.data();
    if (itemData == null) return;
    final item = ItemModel.fromMap(itemDoc.id, itemData);

    // Reserve the item
    await FirebaseFirestore.instance
        .collection('items')
        .doc(claim.itemId)
        .update({
          'status': 'Reserved',
          'reserved_by': claim.claimantId,
          'reserved_at': FieldValue.serverTimestamp(),
        });

    // Chat room expires in 3 days
    final expiresAt = DateTime.now().add(const Duration(days: 3));

    if (claim.isFoundTip) {
      // ── FOUND TIP: finder reported finding a lost item ──────────────────
      // claimantId = the finder   |   ownerId = original lost-item reporter
      final chatRoomRef =
          FirebaseFirestore.instance.collection('chat_rooms').doc();
      await chatRoomRef.set({
        'claim_id': claim.claimId,
        'item_id': claim.itemId,
        'participants': [claim.ownerId, claim.claimantId],
        'last_message': '',
        'last_updated': FieldValue.serverTimestamp(),
        'status': 'active',
        'expires_at': Timestamp.fromDate(expiresAt),
        'typing_status': {claim.ownerId: false, claim.claimantId: false},
        'unread_counts': {claim.ownerId: 0, claim.claimantId: 0},
      });

      // Notify original lost-item reporter 🎉
      await _notificationService.createNotification(
        userId: claim.ownerId,
        title: '🎉 Someone Found Your Item!',
        body:
            'A user reported finding "${item.title}". A chat has been opened so you can arrange the return.',
        type: 'item_found',
        relatedItemId: item.itemId,
        data: {'claim_id': claim.claimId, 'claim_type': 'found_tip'},
      );

      // Notify the finder too
      await _notificationService.createNotification(
        userId: claim.claimantId,
        title: 'Report Approved!',
        body:
            'Your "found item" report for "${item.title}" was approved. A chat has been opened with the owner.',
        type: 'found_tip_approved',
        relatedItemId: item.itemId,
        data: {'claim_id': claim.claimId},
      );
    } else {
      // ── NORMAL CLAIM: person claims ownership of a found item ────────────
      final linkedLostReportId = claim.linkedLostReportId;
      if (linkedLostReportId != null && linkedLostReportId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('items')
            .doc(linkedLostReportId)
            .update({
              'status': 'Resolved',
              'resolved_by_claim_id': claim.claimId,
              'resolved_at': FieldValue.serverTimestamp(),
            });

        await claimsRef.doc(claim.claimId).update({
          'resolved_lost_report_id': linkedLostReportId,
          'linked_lost_report_resolved': true,
          'linked_lost_report_id': FieldValue.delete(),
        });

        await _notificationService.createNotification(
          userId: claim.claimantId,
          title: 'Linked LOST report resolved',
          body: 'Your linked LOST report has been marked as resolved.',
          type: 'lost_report_resolved',
          relatedItemId: linkedLostReportId,
          data: {
            'claim_id': claim.claimId,
            'resolved_lost_report_id': linkedLostReportId,
          },
        );
      }

      final chatRoomRef =
          FirebaseFirestore.instance.collection('chat_rooms').doc();
      await chatRoomRef.set({
        'claim_id': claim.claimId,
        'item_id': claim.itemId,
        'participants': [item.userId, claim.claimantId],
        'last_message': '',
        'last_updated': FieldValue.serverTimestamp(),
        'status': 'active',
        'expires_at': Timestamp.fromDate(expiresAt),
        'typing_status': {
          item.userId: false,
          claim.claimantId: false,
        },
        'unread_counts': {
          item.userId: 0,
          claim.claimantId: 0,
        },
      });

      await _notificationService.createNotification(
        userId: item.userId,
        title: 'Claim Approved & Chat Opened!',
        body:
            'A claim for "${item.title}" was approved. A secure private chat has been opened in your Chat Hub.',
        type: 'report_reserved',
        relatedItemId: item.itemId,
        data: {'claim_id': claim.claimId},
      );

      await _notificationService.createNotification(
        userId: claim.claimantId,
        title: 'Claim Approved & Chat Opened!',
        body:
            'Your claim for "${item.title}" is approved. A secure private chat has been opened.',
        type: 'report_reserved',
        relatedItemId: item.itemId,
        data: {'claim_id': claim.claimId},
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Claim approved.')));
    }
  }


  Future<void> _rejectClaim(ClaimModel claim) async {
    await FirebaseFirestore.instance
        .collection('claims')
        .doc(claim.claimId)
        .update({'status': 'Rejected'});
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Claim rejected.')));
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  void _showClaimDetails(
    ItemModel targetItem,
    ClaimModel claim,
    String claimerName,
  ) {
    if (claim.isFoundTip) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoundTipDetailsScreen(
            targetItem: targetItem,
            claim: claim,
            claimerName: claimerName,
            onApprove: _approveClaim,
            onReject: _rejectClaim,
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        final linkedReportId = claim.linkedLostReportId;
        if (linkedReportId == null || linkedReportId.isEmpty) {
          return const AppConfirmationDialog(
            title: 'Claim Details',
            message: 'No linked LOST report.',
            confirmText: 'Done',
            cancelText: null,
          );
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('items').doc(linkedReportId).get(),
              builder: (context, linkedSnapshot) {
                if (linkedSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: FoundItLoadingIndicator());
                }

                final linkedData = linkedSnapshot.data?.data();
                final linkedLostReport = linkedData == null
                    ? null
                    : ItemModel.fromMap(linkedSnapshot.data!.id, linkedData as Map<String, dynamic>);

                return _buildClaimDetailsDialogUI(
                  context: context,
                  targetItem: targetItem,
                  claim: claim,
                  claimerName: claimerName,
                  linkedLostReport: linkedLostReport,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildClaimDetailsDialogUI({
    required BuildContext context,
    required ItemModel targetItem,
    required ClaimModel claim,
    required String claimerName,
    required ItemModel? linkedLostReport,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.adminVerificationSurfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.adminVerificationBorderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Claim Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.adminVerificationInk),
                ),
                const SizedBox(height: 4),
                Text('By $claimerName', style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.adminVerificationSurfacePanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.adminVerificationBorderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Proof', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  claim.proofDesc,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (claim.similarityScore != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (claim.similarityScore! < AIService.lowSimilarityThreshold) ? Colors.orange.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (claim.similarityScore! < AIService.lowSimilarityThreshold) ? Colors.orange.shade300 : Colors.green.shade300),
              ),
              child: Text(
                'AI Match ${claim.similarityScore!.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          const Text('Comparison', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.adminVerificationComparisonTitle)),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildComparisonPanel(
                    heading: 'Claimed FOUND Item',
                    item: targetItem,
                    accent: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  if (linkedLostReport != null)
                    _buildComparisonPanel(
                      heading: 'Linked LOST Report',
                      item: linkedLostReport,
                      accent: Colors.red,
                    )
                  else
                    _buildComparisonPlaceholder(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonPanel({
    required String heading,
    required ItemModel item,
    required Color accent,
  }) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(fontWeight: FontWeight.bold, color: accent),
          ),
          const SizedBox(height: 12),
          if (item.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: double.infinity,
                  height: 160,
                  alignment: Alignment.center,
                  color: Colors.grey.shade100,
                  child: const Text('Image not available'),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade100,
              ),
              child: const Text('No image uploaded'),
            ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaPill('Type', item.postType),
              _buildMetaPill('Category', item.category),
              _buildMetaPill('Status', item.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (item.specificLocation?.isNotEmpty == true)
                  ? '${item.specificLocation} (${item.locationName})'
                  : item.locationName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.adminVerificationPillSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.adminVerificationMutedInk,
        ),
      ),
    );
  }

  Widget _buildComparisonPlaceholder() {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade50,
      ),
      child: const Center(
        child: Text(
          'Linked LOST report could not be loaded.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showReportDetails(ItemModel item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle Indicator
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.adminVerificationSurfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.adminVerificationBorderSoft,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.adminVerificationInk,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(item.timestamp),
                              style: const TextStyle(
                                color: AppColors.adminVerificationMutedInk,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Hero Image
                      if (item.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (_, __, ___) =>
                                _buildImagePlaceholder(),
                          ),
                        )
                      else
                        _buildImagePlaceholder(),
                      const SizedBox(height: 24),

                      // Refined two-column details
                      _detailRow('Type', item.postType),
                      _detailRow('Category', item.category),
                      _detailRow('Status', item.status),
                      _detailRow(
                        'Location',
                        item.specificLocation?.isNotEmpty == true
                            ? '${item.specificLocation} (${item.locationName})'
                            : item.locationName,
                      ),
                      const SizedBox(height: 8),

                      // Description Section
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.adminVerificationInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF4A4A5A),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Sticky Bottom Action Bar
              Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.adminVerificationBorderSoft,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.adminVerificationInk,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                            color: AppColors.adminVerificationBorderSoft,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (item.location != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openReportMap(item);
                          },
                          icon: const Icon(PhosphorIconsRegular.mapTrifold, size: 18),
                          label: const Text(
                            'View Map',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.adminVerificationInk,
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 220,
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

  void _openReportMap(ItemModel item) {
    if (item.location == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AdminReportMapScreen(item: item)),
    );
  }
}

class _AdminReportMapScreen extends StatelessWidget {
  final ItemModel item;

  const _AdminReportMapScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    final location = item.location!;
    final latLng = LatLng(location.latitude, location.longitude);

    return Scaffold(
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
    );
  }
}
