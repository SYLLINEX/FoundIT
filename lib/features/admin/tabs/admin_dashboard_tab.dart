import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/item_model.dart';
import '../../../widgets/found_it_loading_indicator.dart';
import '../../../widgets/item_card.dart';
import '../../reports/item_details_screen.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  String _selectedCategory = 'All Items';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: FoundItLoadingIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading items.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No items found.'));
          }

          var items = snapshot.data!.docs
              .map((doc) => ItemModel.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ))
              .toList();

          // Filter items based on selected category
          if (_selectedCategory == 'Lost Items') {
            items = items
                .where((item) => item.postType.toLowerCase() == 'lost')
                .toList();
          } else if (_selectedCategory == 'Found Items') {
            items = items
                .where((item) => item.postType.toLowerCase() == 'found')
                .toList();
          }

          return Column(
            children: [
              // Filter Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E2EA),
                        ),
                      ),
                      child: PopupMenuButton<String>(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (String value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'All Items',
                            child: Row(
                              children: [
                                Icon(Icons.category, size: 20),
                                SizedBox(width: 8),
                                Text('All Items'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'Lost Items',
                            child: Row(
                              children: [
                                Icon(Icons.search, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Lost Items'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'Found Items',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 20, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Found Items'),
                              ],
                            ),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.filter_list, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _selectedCategory,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 8,
                    bottom: 100,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ItemDetailsScreen(
                                  item: item,
                                  isAdminView: true,
                                ),
                              ),
                            );
                          },
                          child: ItemCard(
                            imageUrl: item.imageUrl,
                            title: item.title,
                            status: item.postType.toUpperCase(),
                            location: (item.specificLocation != null &&
                                    item.specificLocation!.isNotEmpty)
                                ? item.specificLocation!
                                : item.locationName,
                            timeText: _formatTime(item.timestamp),
                            reporterName: item.reporterName ?? 'Unknown',
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditSnackbar();
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(context, item);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit feature coming soon')),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  void _showDeleteConfirmation(BuildContext context, ItemModel item) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
            'Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteItem(item.itemId);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await FirebaseFirestore.instance.collection('items').doc(itemId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item: $e')),
      );
    }
  }
}
