import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../../models/claim_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'item_details_screen.dart';
import 'edit_report_screen.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../widgets/found_it_loading_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  String _selectedFilter = 'All';
  String _viewType = 'Reports';

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.only(
              top: 50,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.nightfall,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'My Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Segmented Toggle for Reports vs Claims
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _viewType = 'Reports'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _viewType == 'Reports'
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'My Reports',
                                style: TextStyle(
                                  color: _viewType == 'Reports'
                                      ? AppColors.nightfall
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _viewType = 'Claims'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _viewType == 'Claims'
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'My Claims',
                                style: TextStyle(
                                  color: _viewType == 'Claims'
                                      ? AppColors.nightfall
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_viewType == 'Reports') ...[
                  const SizedBox(height: 16),
                  // Custom Tab Bar for filters
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton('All'),
                        _buildTabButton('Pending'),
                        _buildTabButton('Open'),
                        _buildTabButton('Resolved'),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: userId.isEmpty
                ? const Center(child: Text('Please log in to see your activity'))
                : _viewType == 'Reports'
                    ? _buildReportsStream(userId)
                    : _buildClaimsStream(userId),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text) {
    final isSelected = _selectedFilter == text;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = text;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColors.nightfall : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportsStream(String userId) {
    return StreamBuilder<List<ItemModel>>(
      stream: _databaseService.getUserItemsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: FoundItLoadingIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading reports: ${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No reports found.'));
        }

        var items = snapshot.data!;

        // Filter items
        if (_selectedFilter == 'Open') {
          items = items
              .where(
                (item) =>
                    item.status.toLowerCase() == 'open' ||
                    item.status.toLowerCase() == 'active' ||
                    item.status.toLowerCase() == 'matched' ||
                    item.status.toLowerCase() == 'reserved',
              )
              .toList();
        } else if (_selectedFilter == 'Pending') {
          items = items
              .where(
                (item) =>
                    item.status.toLowerCase() == 'pending for approval' ||
                    item.status.toLowerCase() == 'pending',
              )
              .toList();
        } else if (_selectedFilter == 'Resolved') {
          items = items
              .where(
                (item) =>
                    item.status.toLowerCase() == 'resolved' ||
                    item.status.toLowerCase() == 'claimed',
              )
              .toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 100,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildReportItem(items[index]);
          },
        );
      },
    );
  }

  Widget _buildClaimsStream(String userId) {
    return StreamBuilder<List<ClaimModel>>(
      stream: _databaseService.getUserClaimsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: FoundItLoadingIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading claims: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('You have not submitted any claims.'));
        }

        final claims = snapshot.data!;
        
        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
          itemCount: claims.length,
          itemBuilder: (context, index) {
            return _buildClaimItem(claims[index]);
          },
        );
      },
    );
  }

  Widget _buildClaimItem(ClaimModel claim) {
    final status = claim.status.toUpperCase();
    Color statusBgColor = Colors.grey[200]!;
    Color statusColor = Colors.grey[800]!;
    
    if (status == 'APPROVED') {
       statusBgColor = Colors.green[100]!;
       statusColor = Colors.green[700]!;
    } else if (status == 'PENDING') {
       statusBgColor = Colors.orange[100]!;
       statusColor = Colors.orange[700]!;
    } else if (status == 'REJECTED') {
       statusBgColor = Colors.red[100]!;
       statusColor = Colors.red[700]!;
    }
    
    final formattedDate = DateFormat('MMM dd, yyyy').format(claim.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('items').doc(claim.itemId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Center(child: Text('Loading item details...')),
            );
          }
          final itemData = snapshot.data!.data() as Map<String, dynamic>?;
          if (itemData == null) {
            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text('Item not found')),
            );
          }
          
          final item = ItemModel.fromMap(snapshot.data!.id, itemData);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemDetailsScreen(item: item),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: item.imageUrl.isNotEmpty
                       ? ClipRRect(
                           borderRadius: BorderRadius.circular(12),
                           child: CachedNetworkImage(
                             imageUrl: item.imageUrl,
                             fit: BoxFit.cover,
                             placeholder: (context, url) => Shimmer.fromColors(
                               baseColor: Colors.grey[300]!,
                               highlightColor: Colors.grey[100]!,
                               child: Container(color: Colors.white),
                             ),
                             errorWidget: (context, url, error) => const Icon(Icons.image, color: Colors.grey),
                           ),
                         )
                       : const Icon(Icons.image, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Claimed on $formattedDate', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildReportItem(ItemModel item) {
    // Determine status styling
    final status = item.status.toUpperCase();
    Color statusColor;
    Color statusBgColor;
    IconData leadingIcon;
    Color iconColor;
    Color iconBgColor;

    if (status == 'RESOLVED' || status == 'CLAIMED') {
      statusColor = Colors.green[700]!;
      statusBgColor = Colors.green[100]!;
      leadingIcon = Icons.check_circle;
      iconColor = Colors.green;
      iconBgColor = Colors.green[50]!;
    } else if (status == 'PENDING' || status == 'PENDING FOR APPROVAL') {
      statusColor = Colors.orange[700]!;
      statusBgColor = Colors.orange[100]!;
      leadingIcon = Icons.motion_photos_on; 
      iconColor = Colors.orange;
      iconBgColor = Colors.orange[50]!;
    } else if (status == 'MATCHED') {
      statusColor = Colors.purple[700]!;
      statusBgColor = Colors.purple[100]!;
      leadingIcon = Icons.handshake;
      iconColor = Colors.purple;
      iconBgColor = Colors.purple[50]!;
    } else {
      statusColor = Colors.blue[700]!;
      statusBgColor = Colors.blue[100]!;
      leadingIcon = Icons.error_outline;
      iconColor = Colors.blue;
      iconBgColor = Colors.blue[50]!;
    }

    final formattedDate = DateFormat('MMM dd, yyyy').format(item.timestamp);
    final subtitlePrefix = item.postType.toLowerCase() == 'lost'
        ? 'Reported Lost'
        : 'Reported Found';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(item.itemId),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.6,
          children: [
            SlidableAction(
              onPressed: (context) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditReportScreen(item: item),
                  ),
                );
              },
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            const SizedBox(width: 8),
            SlidableAction(
              onPressed: (context) async {
                final confirm = await showAppConfirmationDialog<bool>(
                  context: context,
                  title: 'Delete Report?',
                  message: 'This action cannot be undone.',
                  confirmText: 'Delete',
                  cancelText: 'Cancel',
                  confirmColor: Colors.red,
                );

                if (confirm == true) {
                  await _databaseService.deleteItem(item.itemId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report deleted successfully'),
                      ),
                    );
                  }
                }
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemDetailsScreen(item: item),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leadingIcon, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$subtitlePrefix • $formattedDate',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'ACTIVE' ? 'OPEN' : status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
