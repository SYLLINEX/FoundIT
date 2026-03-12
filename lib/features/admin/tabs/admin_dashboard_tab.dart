import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/claim_model.dart';
import '../../../models/item_model.dart';

class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('items').snapshots(),
            builder: (context, itemSnap) {
              int pendingItems = 0;
              int unresolvedLost = 0;
              int foundItems = 0;
              
              if (itemSnap.hasData) {
                for (var doc in itemSnap.data!.docs) {
                  final item = ItemModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                  if (item.status == 'Pending') pendingItems++;
                  if ((item.status == 'Active' || item.status == 'Open') && item.postType == 'Lost') unresolvedLost++;
                  if ((item.status == 'Active' || item.status == 'Open') && item.postType == 'Found') foundItems++;
                }
              }
              
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard('Pending Verifications', '$pendingItems', Icons.verified_user, Colors.orange),
                  _buildStatCard('Unresolved Lost', '$unresolvedLost', Icons.error_outline, Colors.red),
                  _buildStatCard('Found Items', '$foundItems', Icons.inventory_2, Colors.green),
                  _buildStatCard('Success Rate', '64%', Icons.auto_graph, Colors.blue),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Action Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF333345),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('claims').where('status', isEqualTo: 'Pending').limit(5).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Text('No pending actions required.');
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final claim = ClaimModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                  // Nested FutureBuilder to get the Item and User data
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('items').doc(claim.itemId).get(),
                    builder: (context, itemSnap) {
                      String itemName = 'Unknown Item';
                      if (itemSnap.hasData && itemSnap.data!.exists) {
                        final itemData = itemSnap.data!.data() as Map<String, dynamic>?;
                        itemName = itemData?['title'] ?? 'Unknown Item';
                      }
                      
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(claim.claimantId).get(),
                        builder: (context, userSnap) {
                          String userName = 'User';
                          if (userSnap.hasData && userSnap.data!.exists) {
                            final userData = userSnap.data!.data() as Map<String, dynamic>?;
                            userName = userData?['username'] ?? 'User';
                          }

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              title: Text(
                                itemName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Claimed by $userName • ${_formatTime(claim.timestamp)}'),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.chevron_right, size: 20),
                              ),
                            ),
                          );
                        }
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
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
}

