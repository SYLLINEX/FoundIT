import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../models/item_model.dart';
import '../claims/claim_item_screen.dart';
import '../claims/found_this_item_screen.dart';
import '../../widgets/found_it_loading_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class ItemDetailsScreen extends StatefulWidget {
  final ItemModel item;
  final bool isAdminView;

  const ItemDetailsScreen({
    super.key,
    required this.item,
    this.isAdminView = false,
  });

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
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

  double? get _distanceKm {
    if (_userPosition == null || widget.item.location == null) return null;
    final meters = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      widget.item.location!.latitude,
      widget.item.location!.longitude,
    );
    return meters / 1000;
  }

  String _formatDistanceKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  bool _canClaim(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'open' || normalized == 'active';
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'open' || normalized == 'active')
      return AppColors.statusFound;
    if (normalized == 'pending' || normalized == 'pending for approval')
      return Colors.orange;
    if (normalized == 'reserved') return Colors.purple;
    if (normalized == 'resolved') return Colors.green;
    return Colors.grey;
  }

  String _statusLabel(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'active') return 'OPEN';
    return status.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
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
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(color: Colors.white),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.mist,
                child: const Icon(PhosphorIconsRegular.imageBroken, size: 50),
              ),
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
                child: const Icon(
                  PhosphorIconsRegular.caretLeft,
                  color: Colors.white,
                  size: 20,
                ),
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
                            color: item.postType.toLowerCase() == 'found'
                                ? AppColors.statusFound
                                : AppColors.statusLost,
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
                    // Location Info Card
                    _buildInfoCard(
                      icon: PhosphorIconsFill.mapPin,
                      title: 'Location',
                      value:
                          (item.specificLocation != null &&
                              item.specificLocation!.isNotEmpty)
                          ? '${item.specificLocation} (${item.locationName})'
                          : item.locationName,
                      distanceKm: _distanceKm,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: PhosphorIconsFill.calendarBlank,
                      title: 'Date',
                      value: DateFormat(
                        'MMM d, yyyy - hh:mm a',
                      ).format(item.timestamp),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: PhosphorIconsFill.tag,
                      title: 'Category',
                      value: item.category,
                    ),

                    const SizedBox(height: 24),

                    // Description
                    Row(
                      children: const [
                        Icon(
                          PhosphorIconsRegular.info,
                          size: 20,
                          color: AppColors.nightfall,
                        ),
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
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(item.userId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: FoundItLoadingIndicator());
                        }

                        String username = 'Unknown User';
                        String profileImg = '';

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          username = data['username'] ?? 'Unknown User';
                          profileImg = data['profile_img'] ?? '';
                        }

                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: profileImg.isNotEmpty
                                  ? NetworkImage(profileImg)
                                  : null,
                              child: profileImg.isEmpty
                                  ? const Icon(PhosphorIconsRegular.user, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: AppColors.dusk,
                                    fontSize: 14,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Reported By: '),
                                    TextSpan(
                                      text: username,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.nightfall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
                          icon: const Icon(
                            PhosphorIconsRegular.mapTrifold,
                            color: AppColors.deepLavender,
                          ),
                          label: const Text(
                            'Show on the map',
                            style: TextStyle(
                              color: AppColors.deepLavender,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: AppColors.deepLavender,
                            ),
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
                color: _statusColor(item.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(item.status),
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
      bottomSheet: _buildBottomSheet(context, item),
    );
  }

  Widget _buildBottomSheet(BuildContext context, ItemModel item) {
    if (widget.isAdminView) return const SizedBox();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == item.userId) return const SizedBox();

    final isLostReport = item.postType.toLowerCase() == 'lost';

    return StreamBuilder<DocumentSnapshot>(
      stream: currentUser != null
          ? FirebaseFirestore.instance
              .collection('admins')
              .doc(currentUser.uid)
              .snapshots()
          : const Stream.empty(),
      builder: (context, adminSnapshot) {
        final isAdmin = adminSnapshot.hasData && adminSnapshot.data!.exists;
        if (isAdmin) return const SizedBox();

        return Container(
          color: const Color(0xFFF2F2F6),
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 16),
          child: ElevatedButton(
            onPressed: _canClaim(item.status)
                ? () {
                    if (isLostReport) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FoundThisItemScreen(lostItem: item),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClaimItemScreen(item: item),
                        ),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLostReport
                  ? AppColors.statusFound   // green tint for positive "I found it"
                  : AppColors.deepLavender, // purple for claim
              disabledBackgroundColor: Colors.grey,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLostReport
                      ? PhosphorIconsRegular.handCoins
                      : PhosphorIconsRegular.handWaving,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _canClaim(item.status)
                      ? (isLostReport ? 'I Found This Item!' : 'Claim This Item')
                      : 'Item Not Available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    double? distanceKm,
  }) {
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
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                if (distanceKm != null) ...
                  [
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.nightfall.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDistanceKm(distanceKm),
                        style: const TextStyle(
                          color: AppColors.nightfall,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

} // end _ItemDetailsScreenState

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
          icon: const Icon(
            PhosphorIconsRegular.caretLeft,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: latLng, zoom: 16),
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
          ),
        },
      ),
    );
  }
}
