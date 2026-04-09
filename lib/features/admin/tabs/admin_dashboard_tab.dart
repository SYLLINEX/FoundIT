import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/item_model.dart';
import '../../../widgets/found_it_loading_indicator.dart';
import '../../../widgets/item_card.dart';
import '../../../widgets/app_confirmation_dialog.dart';
import '../../reports/item_details_screen.dart';
import '../../../widgets/expandable_filter_fab.dart';
import '../widgets/admin_header.dart';
import '../../notifications/notifications_screen.dart';
import '../../../services/notification_service.dart';
import '../../../core/utils/app_error_handler.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final List<String> _categories = const [
    'All Items',
    'Lost Items',
    'Found Items',
  ];
  int _selectedCategoryIndex = 0;
  String _selectedCategory = 'All Items';
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            floating: true,
            delegate: _AdminHeaderDelegate(
              minHeight: MediaQuery.of(context).padding.top + 64,
              maxHeight: MediaQuery.of(context).padding.top + 64,
              child: AdminHeader(
                title: 'Dashboard',
                onNotificationTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('items').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: FoundItLoadingIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const SliverFillRemaining(
                  child: Center(child: Text('Error loading items.')),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No items found.')),
                );
              }

              var items = snapshot.data!.docs
                  .map((doc) => ItemModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList();

              if (_selectedCategory == 'Lost Items') {
                items = items.where((item) => item.postType.toLowerCase() == 'lost').toList();
              } else if (_selectedCategory == 'Found Items') {
                items = items.where((item) => item.postType.toLowerCase() == 'found').toList();
              }

              final screenWidth = MediaQuery.of(context).size.width;
              final aspectRatio = screenWidth < 380 ? 0.58 : 0.72;

              return SliverPadding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: 100,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      double? distanceKm;
                      if (_userPosition != null && item.location != null) {
                        final meters = Geolocator.distanceBetween(
                          _userPosition!.latitude,
                          _userPosition!.longitude,
                          item.location!.latitude,
                          item.location!.longitude,
                        );
                        distanceKm = meters / 1000;
                      }
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
                              location: (item.specificLocation != null && item.specificLocation!.isNotEmpty)
                                  ? item.specificLocation!
                                  : item.locationName,
                              timeText: _formatTime(item.timestamp),
                              reporterName: item.reporterName ?? 'Unknown',
                              distanceKm: distanceKm,
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
                                      Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(PhosphorIconsRegular.trash, size: 18, color: Colors.red),
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
                                child: const Icon(PhosphorIconsRegular.dotsThreeVertical, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),
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
              _selectedCategory = _categories[index];
            });
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showEditSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit feature coming soon')));
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
    showAppInputDialog(
      context: context,
      title: 'Delete Item',
      message: 'Please provide a reason for taking down this post. The owner will be notified.',
      hintText: 'Reason for deletion...',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
    ).then((reason) async {
      if (reason != null && reason.isNotEmpty) {
        await _deleteItem(item, reason);
      }
    });
  }

  Future<void> _deleteItem(ItemModel item, String reason) async {
    try {
      await FirebaseFirestore.instance.collection('items').doc(item.itemId).delete();
      
      final notificationService = NotificationService();
      await notificationService.createNotification(
        userId: item.userId,
        title: 'Post Removed',
        body: 'Your post "${item.title}" has been taken down. Reason: $reason',
        type: 'post_deleted',
        relatedItemId: item.itemId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted and owner notified')));
    } catch (e) {
      if (!mounted) return;
      final errorMessage = AppErrorHandler.getMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }
}

class _AdminHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _AdminHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_AdminHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
