import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: AppColors.nightfall,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hi, Alex! 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.mist,
                // Replace with user\'s profile picture 
                child: Icon(Icons.person, color: AppColors.nightfall),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'What are you looking for today?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      hintStyle: TextStyle(color: Colors.black38),
                      prefixIcon: Icon(Icons.search, color: Colors.black38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
