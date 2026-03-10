import 'package:flutter/material.dart';

class MapDashboardScreen extends StatelessWidget {
  const MapDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Items (1km)'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          // Placeholder for Google Map
          Container(
            color: Colors.blueGrey[50],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 100, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Google Maps SDK Integration Goes Here', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),

          // Mock Map Pins
          Positioned(top: 100, left: 150, child: _buildMockPin(Icons.phone_android, Colors.red, 'Lost Phone')),
          Positioned(top: 250, left: 80, child: _buildMockPin(Icons.wallet, Colors.green, 'Found Wallet')),

          // Search Bar Overlay
          Positioned(
            top: 16, left: 16, right: 16,
            child: Card(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  filled: false,
                  suffixIcon: IconButton(icon: const Icon(Icons.mic), onPressed: (){}),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMockPin(IconData icon, Color color, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color, 
            shape: BoxShape.circle, 
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}