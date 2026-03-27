import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/item_card.dart';
import 'widgets/home_header.dart';
import '../../services/database_service.dart';
import '../../models/item_model.dart';
import '../reports/item_details_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../widgets/found_it_loading_indicator.dart';

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
                  child: Center(child: Text('No items found.')),
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

class ExpandableFilterFab extends StatefulWidget {
  final List<String> categories;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;

  const ExpandableFilterFab({
    super.key,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
  });

  @override
  State<ExpandableFilterFab> createState() => _ExpandableFilterFabState();
}

class _ExpandableFilterFabState extends State<ExpandableFilterFab> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 56,
      width: _isExpanded
          ? 260
          : 56, // Expand wider to accommodate chips clearly
      decoration: BoxDecoration(
        color: AppColors.nightfall,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: _isExpanded
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    reverse:
                        true, // Aligns content dynamically from the trailing anchor
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: widget.categories.asMap().entries.map((e) {
                          final isSelected =
                              widget.selectedCategoryIndex == e.key;
                          return GestureDetector(
                            onTap: () {
                              widget.onCategorySelected(e.key);
                              setState(() => _isExpanded = false);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? null
                                    : Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                e.value.replaceAll(' Items', ''),
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.nightfall
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              height: 56,
              width: 56,
              color: Colors.transparent,
              child: Icon(
                _isExpanded
                    ? PhosphorIconsRegular.x
                    : PhosphorIconsRegular.funnel,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
