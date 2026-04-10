import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/item_card.dart';
import 'widgets/home_header.dart';
import '../../services/database_service.dart';
import '../../models/item_model.dart';
import '../reports/item_details_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/expandable_filter_fab.dart';
import '../../widgets/empty_state_view.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';

/// Items within this distance (in km) are shown on the dashboard.
const double _kNearbyRadiusKm = 10.0;

class _ItemDistancePair {
  final ItemModel item;
  final double? distanceKm;
  
  _ItemDistancePair(this.item, this.distanceKm);
}

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

  /// null  → still fetching / permission pending
  /// set   → permission granted and position obtained
  Position? _userPosition;

  /// true while the initial location fetch is in progress
  bool _locationLoading = true;

  /// true when the user denied location permission
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    if (mounted) setState(() => _locationLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationDenied = true;
            _locationLoading = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() {
          _userPosition = pos;
          _locationDenied = false;
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  /// Pull-to-refresh handler – re-fetches the user's location and rebuilds.
  Future<void> _onRefresh() async {
    await _fetchUserLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.deepLavender,
        backgroundColor: Colors.white,
        displacement: 60,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // needed for pull-to-refresh on short lists
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
            // ── Location still loading ──────────────────────────────────────
            if (_locationLoading)
              SliverPadding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: MediaQuery.of(context).size.width < 380 ? 0.58 : 0.72,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildSkeletonItemCard(),
                    childCount: 6,
                  ),
                ),
              )
            // ── Location permission denied ──────────────────────────────────
            else if (_locationDenied)
              const SliverFillRemaining(
                child: EmptyStateView(
                  icon: PhosphorIconsRegular.mapPin,
                  title: 'Location access needed',
                  message:
                      'Grant location permission so we can show items near you. Pull down to try again.',
                ),
              )
            // ── Location ready → stream items ───────────────────────────────
            else
              StreamBuilder<List<ItemModel>>(
                stream: _databaseService.getItemsStream(),
                builder: (context, snapshot) {
                  // Dynamically calculate aspect ratio for smaller screens
                  final screenWidth = MediaQuery.of(context).size.width;
                  final aspectRatio = screenWidth < 380 ? 0.58 : 0.72;

                  if (snapshot.connectionState == ConnectionState.waiting) {
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
                          (context, index) => _buildSkeletonItemCard(),
                          childCount: 6,
                        ),
                      ),
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
                        message:
                            'Try adjusting your filters or search differently.',
                      ),
                    );
                  }

                  var items = snapshot.data!;
                  
                  // Map to distance pairs and filter
                  List<_ItemDistancePair> distancePairs = items.map((item) {
                    double? distKm;
                    if (_userPosition != null && item.location != null) {
                      distKm = Geolocator.distanceBetween(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                        item.location!.latitude,
                        item.location!.longitude,
                      ) / 1000;
                    }
                    return _ItemDistancePair(item, distKm);
                  }).where((pair) {
                    if (_userPosition != null) {
                      if (pair.distanceKm == null) return false;
                      return pair.distanceKm! <= _kNearbyRadiusKm;
                    }
                    return true;
                  }).toList();

                  // ── Category filter ─────────────────────────────────────
                  if (_selectedCategory == 'Lost Items') {
                    distancePairs = distancePairs
                        .where((pair) => pair.item.postType.toLowerCase() == 'lost')
                        .toList();
                  } else if (_selectedCategory == 'Found Items') {
                    distancePairs = distancePairs
                        .where(
                            (pair) => pair.item.postType.toLowerCase() == 'found')
                        .toList();
                  }

                  if (distancePairs.isEmpty) {
                    return const SliverFillRemaining(
                      child: EmptyStateView(
                        icon: PhosphorIconsRegular.mapTrifold,
                        title: 'Nothing nearby',
                        message:
                            'No items were reported within 10 km of your current location. Pull down to refresh.',
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 8,
                      bottom: 100,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pair = distancePairs[index];
                          final item = pair.item;
                          
                          return ItemCard(
                            title: item.title,
                            status: item.status.toLowerCase() == 'reserved' ? 'RESERVED' : item.postType.toUpperCase(),
                            location: (item.specificLocation != null &&
                                    item.specificLocation!.isNotEmpty)
                                ? item.specificLocation!
                                : item.locationName,
                            timeText: timeago.format(item.timestamp),
                            imageUrl: item.imageUrl,
                            reporterName: item.reporterName ?? 'Unknown',
                            distanceKm: pair.distanceKm,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ItemDetailsScreen(item: item),
                                ),
                              );
                            },
                          );
                        },
                        childCount: distancePairs.length,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
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
  Widget _buildSkeletonItemCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(height: 14, width: double.infinity, color: Colors.white),
                    Container(height: 10, width: 80, color: Colors.white),
                    Container(height: 10, width: 100, color: Colors.white),
                    Container(height: 10, width: 90, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

