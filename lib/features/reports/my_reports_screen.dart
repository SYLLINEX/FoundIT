import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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

import '../../widgets/expandable_filter_fab.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/theme_aware_shimmer.dart';
import '../../widgets/empty_state_view.dart';
import '../../core/utils/app_error_handler.dart';

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
  final List<String> _reportFilters = const ['All', 'Open', 'Pending', 'Resolved'];

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _viewType == 'Reports'
          ? Padding(
              padding: const EdgeInsets.only(bottom: 100.0), // Clear the bottom nav bar
              child: ExpandableFilterFab(
                categories: _reportFilters,
                selectedCategoryIndex: _reportFilters.indexOf(_selectedFilter),
                onCategorySelected: (index) {
                  setState(() {
                    _selectedFilter = _reportFilters[index];
                  });
                },
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          // Header
          Container(
            height: MediaQuery.of(context).padding.top + 64,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 12,
            ),
            decoration: const BoxDecoration(
              color: AppColors.nightfall,
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Icon Avatar
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white24,
                  child: Icon(PhosphorIconsRegular.clipboardText, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),

                // Middle: Title
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'My Activity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Track your reports & claims',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Right: Segmented Toggle for Reports vs Claims
                Container(
                  height: 36,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _viewType = 'Reports'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _viewType == 'Reports' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'Reports',
                              style: TextStyle(
                                color: _viewType == 'Reports' ? AppColors.nightfall : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _viewType = 'Claims'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _viewType == 'Claims' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'Claims',
                              style: TextStyle(
                                color: _viewType == 'Claims' ? AppColors.nightfall : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildReportsStream(String userId) {
    return StreamBuilder<List<ItemModel>>(
      stream: _databaseService.getUserItemsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 100,
            ),
            itemCount: 4, // 4 skeletons to fill the screen
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSkeletonCard(),
              );
            },
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading reports: ${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateView(
            icon: PhosphorIconsRegular.clipboardText,
            title: 'No reports found',
            message: 'You haven\'t submitted any reports yet.',
          );
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
          return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSkeletonCard(),
              );
            },
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading claims: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateView(
            icon: PhosphorIconsRegular.handshake,
            title: 'No claims submitted',
            message: 'You haven\'t submitted any claims yet.',
          );
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
            return _buildSkeletonCard();
          }
          final itemData = snapshot.data!.data() as Map<String, dynamic>?;
          if (itemData == null) {
            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    blurRadius: 12,
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
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: item.imageUrl.isNotEmpty
                       ? ClipRRect(
                           borderRadius: BorderRadius.circular(12),
                           child: CachedNetworkImage(
                             imageUrl: item.imageUrl,
                             fit: BoxFit.cover,
                             placeholder: (context, url) => ThemeAwareShimmer(                               child: Container(color: Colors.white),
                             ),
                             errorWidget: (context, url, error) => const Icon(PhosphorIconsRegular.image, color: Colors.grey),
                           ),
                         )
                       : const Icon(PhosphorIconsRegular.image, color: Colors.grey),
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
                  const SizedBox(width: 8),
                  Icon(PhosphorIconsRegular.caretRight, color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ThemeAwareShimmer(        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 60,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(PhosphorIconsRegular.caretRight, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(ItemModel item) {
    // Determine status styling
    final status = item.status.toUpperCase();
    Color statusColor;
    Color statusBgColor;

    if (status == 'RESOLVED' || status == 'CLAIMED') {
      statusColor = Colors.green[700]!;
      statusBgColor = Colors.green[100]!;
    } else if (status == 'PENDING' || status == 'PENDING FOR APPROVAL') {
      statusColor = Colors.orange[700]!;
      statusBgColor = Colors.orange[100]!;
    } else if (status == 'MATCHED') {
      statusColor = Colors.purple[700]!;
      statusBgColor = Colors.purple[100]!;
    } else {
      statusColor = Colors.blue[700]!;
      statusBgColor = Colors.blue[100]!;
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
              icon: PhosphorIconsRegular.pencilSimple,
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
                  try {
                    await _databaseService.deleteItem(item.itemId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Report deleted successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final errorMsg = AppErrorHandler.getMessage(e);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMsg)),
                      );
                    }
                  }
                }
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: PhosphorIconsRegular.trash,
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  blurRadius: 12,
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
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: item.imageUrl.isNotEmpty
                     ? ClipRRect(
                         borderRadius: BorderRadius.circular(12),
                         child: CachedNetworkImage(
                           imageUrl: item.imageUrl,
                           fit: BoxFit.cover,
                           placeholder: (context, url) => ThemeAwareShimmer(                             child: Container(color: Colors.white),
                           ),
                           errorWidget: (context, url, error) => const Icon(PhosphorIconsRegular.image, color: Colors.grey),
                         ),
                       )
                     : const Icon(PhosphorIconsRegular.image, color: Colors.grey),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                Icon(PhosphorIconsRegular.caretRight, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
