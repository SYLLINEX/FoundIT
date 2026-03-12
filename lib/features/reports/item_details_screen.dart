import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../claims/claim_item_screen.dart';

class ItemDetailsScreen extends StatelessWidget {
  final ItemModel item;

  const ItemDetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      body: Stack(
        children: [
          // Background Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: AppColors.mist, child: const Icon(Icons.broken_image, size: 50)),
            ),
          ),
          
          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Main Content
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.nightfall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.postType.toLowerCase() == 'found' ? AppColors.statusFound : AppColors.statusLost,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reported as ${item.postType.toLowerCase()}',
                          style: const TextStyle(
                            color: AppColors.nightfall,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Info Cards
                    _buildInfoCard(
                      icon: PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                      title: 'Location',
                      value: (item.specificLocation != null && item.specificLocation!.isNotEmpty) ? '${item.specificLocation} (${item.locationName})' : item.locationName,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
                      title: 'Date',
                      value: DateFormat('MMM d, yyyy - hh:mm a').format(item.timestamp),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: PhosphorIcons.tag(PhosphorIconsStyle.fill),
                      title: 'Category',
                      value: item.category,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Description
                    Row(
                      children: const [
                        Icon(Icons.info_outline, size: 20, color: AppColors.nightfall),
                        SizedBox(width: 8),
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.nightfall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        item.description,
                        style: const TextStyle(
                          color: Color(0xFF6B6A7C),
                          height: 1.5,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // User Profile Section
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(item.userId).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        String username = 'Unknown User';
                        String profileImg = '';
                        
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          username = data['username'] ?? 'Unknown User';
                          profileImg = data['profile_img'] ?? '';
                        }
                        
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                              child: profileImg.isEmpty
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: AppColors.dusk, fontSize: 14),
                                  children: [
                                    const TextSpan(text: 'Reported By: '),
                                    TextSpan(
                                      text: username,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.nightfall),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (item.location != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ItemMapScreen(item: item),
                              ),
                            );
                          },
                          icon: const Icon(PhosphorIconsRegular.mapTrifold, color: AppColors.deepLavender),
                          label: const Text(
                            'Show on the map',
                            style: TextStyle(color: AppColors.deepLavender, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.deepLavender),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      
                    const SizedBox(height: 120), // Bottom padding for button
                  ],
                ),
              ),
            ),
          ),
          
          // Badge
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4 - 15,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: item.status.toLowerCase() == 'active' ? AppColors.statusFound : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.status.toUpperCase() == 'ACTIVE' ? 'AVAILABLE' : item.status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: FirebaseAuth.instance.currentUser?.uid == item.userId 
        ? const SizedBox() // Hide claim if it's the user's own item
        : Container(
            color: const Color(0xFFF2F2F6),
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClaimItemScreen(item: item),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepLavender,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(PhosphorIconsRegular.handWaving, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Claim This Item',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.deepLavender, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.nightfall,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ItemMapScreen extends StatelessWidget {
  final ItemModel item;
  
  const ItemMapScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.location == null) return const Scaffold();
    
    final latLng = LatLng(item.location!.latitude, item.location!.longitude);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.nightfall,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: latLng,
          zoom: 16,
        ),
        markers: {
          Marker(
            markerId: MarkerId(item.itemId),
            position: latLng,
            infoWindow: InfoWindow(
              title: item.title,
              snippet: item.specificLocation ?? item.locationName,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              item.postType.toLowerCase() == 'lost' 
                ? BitmapDescriptor.hueRed 
                : BitmapDescriptor.hueBlue,
            ),
          )
        },
      ),
    );
  }
}
