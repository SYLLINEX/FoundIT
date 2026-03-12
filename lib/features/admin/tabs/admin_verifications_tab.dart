import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/claim_model.dart';
import '../../../models/item_model.dart';

class AdminVerificationsTab extends StatefulWidget {
  const AdminVerificationsTab({super.key});

  @override
  State<AdminVerificationsTab> createState() => _AdminVerificationsTabState();
}

class _AdminVerificationsTabState extends State<AdminVerificationsTab> {
  String _selectedFilter = 'Reports'; // 'Reports' or 'Claims'
  String _searchQuery = '';

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fact_check_outlined, color: Color(0xFF333345)),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verifications',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333345)),
                      ),
                      Text(
                        'Review pending item reports & claims',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Search Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                    child: const Icon(Icons.filter_list, color: Color(0xFF333345)),
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
          child: _selectedFilter == 'Reports' ? _buildReportsList() : _buildClaimsList(),
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
      stream: FirebaseFirestore.instance.collection('items').where('status', isEqualTo: 'Pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No pending reports.'));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final item = ItemModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = ItemModel.fromMap(docs[index].id, docs[index].data() as Map<String, dynamic>);
            return _buildReportCard(item);
          },
        );
      },
    );
  }

  Widget _buildClaimsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('claims').where('status', isEqualTo: 'Pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No pending claims.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final claim = ClaimModel.fromMap(snapshot.data!.docs[index].id, snapshot.data!.docs[index].data() as Map<String, dynamic>);
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('items').doc(claim.itemId).get(),
              builder: (context, itemSnap) {
                if (!itemSnap.hasData) return const SizedBox();
                final itemData = itemSnap.data!.data();
                if (itemData == null) return const SizedBox();
                
                final item = ItemModel.fromMap(itemSnap.data!.id, itemData as Map<String, dynamic>);
                
                if (_searchQuery.isNotEmpty && !item.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
                  return const SizedBox();
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(claim.claimantId).get(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return const SizedBox();
                    final userData = userSnap.data!.data();
                    final userName = (userData as Map<String, dynamic>?)?['username'] ?? 'User';

                    return _buildClaimCard(item, claim, userName);
                  }
                );
              }
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                Text(_formatTime(item.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.pinkAccent),
                const SizedBox(width: 4),
                Text(item.locationName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _rejectReport(item),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _approveReport(item),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve & Publish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                Text(_formatTime(claim.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Claimed by \$claimerName', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Proof:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(claim.proofDesc, style: const TextStyle(color: Colors.black87, fontSize: 14)),
            const SizedBox(height: 12),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _rejectClaim(claim),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _approveClaim(claim),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve Match'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _approveReport(ItemModel item) async {
    await FirebaseFirestore.instance.collection('items').doc(item.itemId).update({
      'status': 'Open',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report approved and published.')));
    }
  }

  void _rejectReport(ItemModel item) async {
    await FirebaseFirestore.instance.collection('items').doc(item.itemId).update({
      'status': 'Rejected',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report rejected and removed.')));
    }
  }

  void _approveClaim(ClaimModel claim) async {
    await FirebaseFirestore.instance.collection('claims').doc(claim.claimId).update({
      'status': 'Approved',
    });
    // Also, usually claim approval means item is returned
    await FirebaseFirestore.instance.collection('items').doc(claim.itemId).update({
      'status': 'Resolved',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim approved.')));
    }
  }

  void _rejectClaim(ClaimModel claim) async {
    await FirebaseFirestore.instance.collection('claims').doc(claim.claimId).update({
      'status': 'Rejected',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim rejected.')));
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }
}
