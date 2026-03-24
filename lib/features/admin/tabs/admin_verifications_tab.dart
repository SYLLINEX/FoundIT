import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/claim_model.dart';
import '../../../models/item_model.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/found_it_loading_indicator.dart';

class AdminVerificationsTab extends StatefulWidget {
  const AdminVerificationsTab({super.key});

  @override
  State<AdminVerificationsTab> createState() => _AdminVerificationsTabState();
}

class _AdminVerificationsTabState extends State<AdminVerificationsTab> {
  String _selectedFilter = 'Reports'; // 'Reports' or 'Claims'
  String _searchQuery = '';
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row(
              //   children: [
              //     Container(
              //       padding: const EdgeInsets.all(8),
              //       decoration: BoxDecoration(
              //         color: Colors.grey[200],
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //       child: const Icon(
              //         Icons.fact_check_outlined,
              //         color: Color(0xFF333345),
              //       ),
              //     ),
              //     const SizedBox(width: 12),
              //     const Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Text(
              //           'Verifications',
              //           style: TextStyle(
              //             fontSize: 22,
              //             fontWeight: FontWeight.bold,
              //             color: Color(0xFF333345),
              //           ),
              //         ),
              //         Text(
              //           'Review pending item reports & claims',
              //           style: TextStyle(color: Colors.grey, fontSize: 13),
              //         ),
              //       ],
              //     ),
              //   ],
              // ),
              const SizedBox(height: 20),
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
                          Icons.search,
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
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.filter_list,
                      color: Color(0xFF333345),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('Reports'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Claims'),
                ],
              ),
            ],
          ),
        ),
        // List Area
        Expanded(
          child: _selectedFilter == 'Reports'
              ? _buildReportsList()
              : _buildClaimsList(),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF333345) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
          return const Center(child: Text('No pending reports.'));
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
          return const Center(child: Text('No pending claims.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final claim = ClaimModel.fromMap(
              snapshot.data!.docs[index].id,
              snapshot.data!.docs[index].data() as Map<String, dynamic>,
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
                    !item.title.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    )) {
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
                        (userData as Map<String, dynamic>?)?['username'] ??
                        'User';

                    return _buildClaimCard(item, claim, userName);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReportCard(ItemModel item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PENDING REPORT',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatTime(item.timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 14,
                  color: Colors.pinkAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  item.locationName,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reported by: ${item.reporterName ?? "Unknown"}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReportDetails(item),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: item.location == null
                        ? null
                        : () => _openReportMap(item),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Show on map'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _rejectReport(item),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _approveReport(item),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve & Publish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimCard(ItemModel item, ClaimModel claim, String claimerName) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PENDING CLAIM',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatTime(claim.timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Claimed by $claimerName',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Proof:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              claim.proofDesc,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _rejectClaim(claim),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _approveClaim(claim),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve Match'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showApprovalConfirmation(ItemModel item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Approval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to approve this report: "${item.title}"',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'This report will be published publicly and visible to all users. Users nearby will also be notified.',
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approveReport(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirm & Publish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _approveReport(ItemModel item) async {
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

  void _rejectReport(ItemModel item) async {
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

  void _approveClaim(ClaimModel claim) async {
    await FirebaseFirestore.instance
        .collection('claims')
        .doc(claim.claimId)
        .update({'status': 'Approved'});

    final itemDoc = await FirebaseFirestore.instance
        .collection('items')
        .doc(claim.itemId)
        .get();
    final itemData = itemDoc.data();
    if (itemData == null) return;
    final item = ItemModel.fromMap(itemDoc.id, itemData);

    await FirebaseFirestore.instance
        .collection('items')
        .doc(claim.itemId)
        .update({
          'status': 'Reserved',
          'reserved_by': claim.claimantId,
          'reserved_at': FieldValue.serverTimestamp(),
        });

    await _notificationService.createNotification(
      userId: item.userId,
      title: 'Someone found your report',
      body: 'A claim for "${item.title}" was approved by admin.',
      type: 'report_found',
      relatedItemId: item.itemId,
      data: {'claim_id': claim.claimId},
    );

    await _notificationService.createNotification(
      userId: item.userId,
      title: 'Report reserved',
      body:
          'Your report "${item.title}" is now reserved for claimant verification.',
      type: 'report_reserved',
      relatedItemId: item.itemId,
    );

    await _notificationService.createNotification(
      userId: claim.claimantId,
      title: 'Claim approved',
      body:
          'Your claim for "${item.title}" is approved. The item is reserved for you.',
      type: 'report_reserved',
      relatedItemId: item.itemId,
      data: {'claim_id': claim.claimId},
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Claim approved.')));
    }
  }

  void _rejectClaim(ClaimModel claim) async {
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

  void _showReportDetails(ItemModel item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (item.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.imageUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180,
                              color: Colors.grey[200],
                              alignment: Alignment.center,
                              child: const Text('Failed to load image'),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('No image uploaded'),
                        ),
                      const SizedBox(height: 16),
                      _detailRow('Type', item.postType),
                      _detailRow('Category', item.category),
                      _detailRow('Status', item.status),
                      _detailRow(
                        'Location',
                        item.specificLocation?.isNotEmpty == true
                            ? '${item.specificLocation} (${item.locationName})'
                            : item.locationName,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                          if (item.location != null)
                            const SizedBox(width: 8),
                          if (item.location != null)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _openReportMap(item);
                              },
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('Map'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black87, fontSize: 12),
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
        backgroundColor: const Color(0xFF333345),
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
