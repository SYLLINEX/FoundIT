import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/item_card.dart';
import 'widgets/home_header.dart';
import 'widgets/category_tabs.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data to match mockup
    final List<Map<String, dynamic>> dummyItems = [
      {
        'title': 'Blue Car Keys',
        'status': 'LOST',
        'location': 'Library Level 2',
        'timeText': '2 hours ago',
        'imageUrl': 'https://images.unsplash.com/photo-1584820927498-cafe2c1303ba?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      },
      {
        'title': 'Black Leather Wallet',
        'status': 'LOST',
        'location': 'Engineering Block B',
        'timeText': '1 day ago',
        'imageUrl': 'https://images.unsplash.com/photo-1627123424574-724758594e93?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      },
      {
        'title': 'Apple AirPods Pro',
        'status': 'FOUND',
        'location': 'Cafeteria',
        'timeText': '3 hours ago',
        'imageUrl': 'https://images.unsplash.com/photo-1606220588913-b3ae14ee713e?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      },
      {
        'title': 'Hydro Flask Bottle',
        'status': 'FOUND',
        'location': 'Gym Gymnasium',
        'timeText': '5 hours ago',
        'imageUrl': 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.mist,
      body: Column(
        children: [
          const HomeHeader(),
          const SizedBox(height: 24),
          CategoryTabs(
            categories: const ['All Items', 'Lost Items', 'Found Items'],
            onTabSelected: (index) {
              // Handle filtering
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 100), // Bottom padding for custom nav bar
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75, // Adjust for card proportions
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: dummyItems.length,
              itemBuilder: (context, index) {
                final item = dummyItems[index];
                return ItemCard(
                  title: item['title'],
                  status: item['status'],
                  location: item['location'],
                  timeText: item['timeText'],
                  imageUrl: item['imageUrl'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
