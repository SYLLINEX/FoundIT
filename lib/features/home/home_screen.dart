import 'package:flutter/material.dart';
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
  final List<String> _categories = const ['All Items', 'Lost Items', 'Found Items'];
  int _selectedCategoryIndex = 0;
  String _selectedCategory = 'All Items';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: Column(
        children: [
          HomeHeader(
            categories: _categories,
            selectedCategoryIndex: _selectedCategoryIndex,
            onCategorySelected: (index) {
              setState(() {
                _selectedCategoryIndex = index;
                _selectedCategory = _categories[index];
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<ItemModel>>(
              stream: _databaseService.getItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: FoundItLoadingIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading items.'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No items found.'));
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

                return GridView.builder(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 8,
                    bottom: 100,
                  ), // Bottom padding for custom nav bar
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75, // Adjust for card proportions
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
