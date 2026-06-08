import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/claim_model.dart';
import '../../../models/item_model.dart';
import '../../../widgets/found_it_loading_indicator.dart';
import '../widgets/admin_header.dart';
import '../../notifications/notifications_screen.dart';

class AdminAnalyticsTab extends StatelessWidget {
  const AdminAnalyticsTab({super.key});

  List<int> _buildRecentWeekCounts(List<ItemModel> items) {
    final now = DateTime.now();
    final counts = List<int>.filled(7, 0);

    for (final item in items) {
      final diff = now.difference(item.timestamp).inDays;
      if (diff >= 0 && diff < 7) {
        counts[6 - diff]++;
      }
    }
    return counts;
  }

  Map<String, int> _buildCategoryCounts(List<ItemModel> items) {
    final map = <String, int>{};
    for (final item in items) {
      map[item.category] = (map[item.category] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdminHeader(
          title: 'Analytics',
          onNotificationTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 16.0,
              bottom: 140.0,
            ),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('items').snapshots(),
            builder: (context, itemSnap) {
              int pendingItems = 0;
              int unresolvedLost = 0;
              int foundItems = 0;
              int reservedItems = 0;
              final allItems = <ItemModel>[];

              if (itemSnap.hasData) {
                for (var doc in itemSnap.data!.docs) {
                  final item = ItemModel.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  );
                  allItems.add(item);
                  final normalizedStatus = item.status.toLowerCase();
                  if (normalizedStatus == 'pending' ||
                      normalizedStatus == 'pending for approval') {
                    pendingItems++;
                  }
                  if ((item.status == 'Active' || item.status == 'Open') &&
                      item.postType == 'Lost') {
                    unresolvedLost++;
                  }
                  if ((item.status == 'Active' || item.status == 'Open') &&
                      item.postType == 'Found') {
                    foundItems++;
                  }
                  if (normalizedStatus == 'reserved') {
                    reservedItems++;
                  }
                }
              }

              final trendCounts = _buildRecentWeekCounts(allItems);
              final categoryCounts = _buildCategoryCounts(
                allItems
                    .where((e) => e.postType.toLowerCase() == 'lost')
                    .toList(),
              );
              final totalHandled = allItems.isEmpty
                  ? 0
                  : allItems.where((e) {
                      final s = e.status.toLowerCase();
                      return s == 'resolved' || s == 'reserved';
                    }).length;
              final successRate = allItems.isEmpty
                  ? 0
                  : ((totalHandled / allItems.length) * 100).round();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.24,
                    children: [
                      _buildStatCard(
                        context,
                        'Pending Verifications',
                        '$pendingItems',
                        PhosphorIconsRegular.shieldCheck,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        context,
                        'Unresolved Lost',
                        '$unresolvedLost',
                        PhosphorIconsRegular.warningCircle,
                        Colors.red,
                      ),
                      _buildStatCard(
                        context,
                        'Found Items',
                        '$foundItems',
                        PhosphorIconsRegular.package,
                        Colors.green,
                      ),
                      _buildStatCard(
                        context,
                        'Reserved',
                        '$reservedItems',
                        PhosphorIconsRegular.bookmarkSimple,
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildTrendCard(trendCounts, successRate),
                  const SizedBox(height: 14),
                  _buildCategoryCard(context, categoryCounts),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Success Stories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('claims')
                .where('status', isEqualTo: 'Approved')
                .orderBy('created_at', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: FoundItLoadingIndicator());
              }
              if (snap.hasError) {
                return const Text('Error loading success stories.');
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Text('No recent success stories found yet. Keep up the good work!');
              }
              return Column(
                children: snap.data!.docs.map((doc) {
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
                      String itemName = 'Unknown Item';
                      if (itemSnap.hasData && itemSnap.data!.exists) {
                        final itemData =
                            itemSnap.data!.data() as Map<String, dynamic>?;
                        itemName = itemData?['title'] ?? 'Unknown Item';
                      }

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(claim.claimantId)
                            .get(),
                        builder: (context, userSnap) {
                          String userName = 'User';
                          if (userSnap.hasData && userSnap.data!.exists) {
                            final userData =
                                userSnap.data!.data() as Map<String, dynamic>?;
                            userName = userData?['username'] ?? 'User';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE9EAF0)),
                            ),
                            elevation: 0,
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8F5E9),
                                child: Icon(PhosphorIconsFill.checkCircle, color: Colors.green),
                              ),
                              title: Text(
                                '$itemName returned!',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Claimed by $userName\nAI Match Score: ${claim.similarityScore?.toStringAsFixed(1) ?? 'N/A'}%'),
                              trailing: const Icon(PhosphorIconsRegular.caretRight, size: 16),
                            ),
                          );
                        },
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
     ),
    ),
   ],
  );
}

  Widget _buildTrendCard(List<int> trendCounts, int successRate) {
    final maxValue = trendCounts.isEmpty
        ? 1
        : trendCounts.reduce((a, b) => a > b ? a : b).clamp(1, 9999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF333345), Color(0xFF4A4A69)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsRegular.chartLineUp, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Weekly Activity Trend',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '$successRate% solved',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(trendCounts.length, (index) {
                final ratio = trendCounts[index] / maxValue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 10 + (ratio * 60),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, int> categoryCounts) {
    final sorted = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();
    final maxValue = top.isEmpty ? 1 : top.first.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(PhosphorIconsRegular.chartBar),
              SizedBox(width: 8),
              Text(
                'Top Missing Item Categories',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (top.isEmpty)
            const Text('No category data yet.')
          else
            ...top.map((entry) {
              final ratio = entry.value / maxValue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('${entry.value}'),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: ratio,
                        backgroundColor: const Color(0xFFEAEAF0),
                        color: const Color(0xFF333345),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    MaterialColor color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
