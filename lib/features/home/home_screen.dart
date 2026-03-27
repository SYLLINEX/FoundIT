import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/item_card.dart';
import 'widgets/home_header.dart';
import '../../services/database_service.dart';
import '../../models/item_model.dart';
import '../reports/item_details_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../widgets/found_it_loading_indicator.dart';
import '../../widgets/expandable_filter_fab.dart';
import '../../widgets/empty_state_view.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _databaseService = DatabaseService();
  final List<String> _categories = const [
    'All Items',
    'Lost Items',
    'Found Items',
  ];
  int _selectedCategoryIndex = 0;
  String _selectedCategory = 'All Items';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            floating: true,
            delegate: _HomeHeaderDelegate(
              minHeight: MediaQuery.of(context).padding.top + 64,
              maxHeight: MediaQuery.of(context).padding.top + 64,
              child: const HomeHeader(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          StreamBuilder<List<ItemModel>>(
            stream: _databaseService.getItemsStream(),
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

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyStateView(
                    icon: PhosphorIconsRegular.folderOpen,
                    title: 'No items found',
                    message: 'Try adjusting your filters or search differently.',
                  ),
                );
              }

              var items = snapshot.data!;

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

              // Dynamically calculate aspect ratio for smaller screens
              final screenWidth = MediaQuery.of(context).size.width;
              // Base ratio is 0.75 for standard screens. Decrease ratio to limit overflow on narrow screens.
              // At 0.58 we provide enough vertical padding for 4 lines of scaled text.
              final aspectRatio = screenWidth < 380 ? 0.58 : 0.72;

              return SliverPadding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: 100,
                ), // Bottom padding for custom nav bar
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: aspectRatio, // Dynamic card proportions
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    return ItemCard(
                      title: item.title,
                      status: item.postType.toUpperCase(),
                      location:
                          (item.specificLocation != null &&
                              item.specificLocation!.isNotEmpty)
                          ? item.specificLocation!
                          : item.locationName,
                      timeText: timeago.format(item.timestamp),
                      imageUrl: item.imageUrl,
                      reporterName: item.reporterName ?? 'Unknown',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemDetailsScreen(item: item),
                          ),
                        );
                      },
                    );
                  }, childCount: items.length),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 100.0,
        ), // Clear the bottom nav bar
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
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _HomeHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_HomeHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

