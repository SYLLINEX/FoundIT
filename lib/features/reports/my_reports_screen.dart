import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'item_details_screen.dart';
import 'edit_report_screen.dart';
import '../../widgets/found_it_loading_indicator.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  String _selectedFilter = 'All';

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
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'My Reports',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Custom Tab Bar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
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
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: userId.isEmpty
                ? const Center(child: Text('Please log in to see your reports'))
                : StreamBuilder<List<ItemModel>>(
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
                      } else if (_selectedFilter == 'Pending for Approval') {
                        items = items
                            .where(
                              (item) =>
                                  item.status.toLowerCase() ==
                                      'pending for approval' ||
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
                  ),
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

  Widget _buildReportItem(ItemModel item) {
    // Determine status styling
    final status = item.status.toUpperCase();
    Color statusColor;
    Color statusBgColor;
    IconData leadingIcon;
    Color iconColor;
    Color iconBgColor;

    // Default matching "Active" or "Open" as OPEN/PENDING depending on logic.
    // For specific match to the UI:
    if (status == 'RESOLVED' || status == 'CLAIMED') {
      statusColor = Colors.green[700]!;
      statusBgColor = Colors.green[100]!;
      leadingIcon = Icons.check_circle;
      iconColor = Colors.green;
      iconBgColor = Colors.green[50]!;
    } else if (status == 'PENDING' || status == 'PENDING FOR APPROVAL') {
      statusColor = Colors.orange[700]!;
      statusBgColor = Colors.orange[100]!;
      leadingIcon = Icons.motion_photos_on; // similar to dotted spinner
      iconColor = Colors.orange;
      iconBgColor = Colors.orange[50]!;
    } else if (status == 'MATCHED') {
      statusColor = Colors.purple[700]!;
      statusBgColor = Colors.purple[100]!;
      leadingIcon = Icons.handshake;
      iconColor = Colors.purple;
      iconBgColor = Colors.purple[50]!;
    } else {
      // OPEN or ACTIVE
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
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Report'),
                    content: const Text(
                      'Are you sure you want to delete this report?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
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
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
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
                // Texts
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
                // Status badge
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
                // Arrow
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
