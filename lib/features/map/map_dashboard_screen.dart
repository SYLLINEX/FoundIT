import 'dart:async';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/item_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../core/constants/map_style.dart';
import '../reports/item_details_screen.dart';
import '../../widgets/found_it_loading_indicator.dart';
import '../../core/theme/app_colors.dart';

class MapDashboardScreen extends StatefulWidget {
  const MapDashboardScreen({super.key});

  @override
  State<MapDashboardScreen> createState() => _MapDashboardScreenState();
}

class _MapDashboardScreenState extends State<MapDashboardScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  MapType _currentMapType = MapType.normal;

  StreamSubscription<List<ItemModel>>? _itemsSubscription;
  List<ItemModel> _allItems = [];

  // Filters State
  bool _showLost = true;
  bool _showFound = true;
  bool _showLabels = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    
    // We do NOT add searchController listener here to prevent maps lag.
    // Instead we use ValueListenableBuilder in the UI.
  }

  void _subscribeToNearbyItems(Position position) {
    _itemsSubscription?.cancel();

    _itemsSubscription = _databaseService
        .getItemsWithinRadiusStream(
          GeoPoint(position.latitude, position.longitude),
          radiusInKm: 10.0, // 10km Radius Proximity Search Feature
        )
        .listen((items) {
          _allItems = items;
          _applyFiltersAndBuildMarkers();
        });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _itemsSubscription?.cancel();
    super.dispose();
  }

  void _applyFiltersAndBuildMarkers() {
    // Map markers remain unaffected by the text query to prevent lag on map rebuilding.
    // The search bar is now purely an overlay auto-suggest.
    final filteredData = _getFilteredItems(_allItems);
    _updateMarkers(filteredData);
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await _locationService.getCurrentLocation();
      setState(() {
        _currentPosition = position;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 16.0,
            ),
          ),
        );
      }

      // Automatically fetch items within 10km radius
      _subscribeToNearbyItems(position);
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  void _recenterToCurrentLocation() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 16.0,
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.setMapStyle(mapStyleJson); // Apply the silver theme

    if (_currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  Future<BitmapDescriptor> _getCustomMarker(String title, bool isLost) async {
    if (!_showLabels) {
      return BitmapDescriptor.defaultMarkerWithHue(
        isLost ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
      );
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;

    // Draw Pin
    final Paint paint = Paint()
      ..color = isLost ? const Color(0xFFD32F2F) : const Color(0xFF388E3C);
    final Offset center = const Offset(size / 2, size / 2 - 15);
    canvas.drawCircle(center, 12.0, paint);
    canvas.drawCircle(center, 8.0, Paint()..color = Colors.white);
    canvas.drawCircle(center, 5.0, paint);

    // Draw Text Background and Text
    TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: title,
      style: const TextStyle(
        fontSize: 14.0,
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();

    final double textWidth = textPainter.width;
    final double textHeight = textPainter.height;
    final Rect bgRect = Rect.fromLTWH(
      size / 2 - textWidth / 2 - 6,
      size / 2 + 2,
      textWidth + 12,
      textHeight + 6,
    );

    final RRect rRect = RRect.fromRectAndRadius(
      bgRect,
      const Radius.circular(6),
    );
    canvas.drawRRect(rRect, Paint()..color = Colors.white);

    // Border
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    textPainter.paint(canvas, Offset(size / 2 - textWidth / 2, size / 2 + 5));

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(uint8List);
  }

  Future<void> _updateMarkers(List<ItemModel> items) async {
    Set<Marker> newMarkers = {};
    for (var item in items) {
      if (item.location == null) continue;
      final isLost = item.postType.toLowerCase() == 'lost';
      final icon = await _getCustomMarker(item.title, isLost);

      newMarkers.add(
        Marker(
          markerId: MarkerId(item.itemId),
          position: LatLng(item.location!.latitude, item.location!.longitude),
          icon: icon,
          onTap: () => _showItemDetailsSheet(item),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  // --- Filtering Logic ---
  List<ItemModel> _getFilteredItems(List<ItemModel> rawItems) {
    return rawItems.where((item) {
      // Type Filter (Lost/Found) - Map markers no longer filter by text to save performance
      bool matchesType = false;
      if (item.postType.toLowerCase() == 'lost' && _showLost) matchesType = true;
      if (item.postType.toLowerCase() == 'found' && _showFound) matchesType = true;
      return matchesType;
    }).toList();
  }

  List<ItemModel> _getSearchResults(String query) {
    final lowerQuery = query.toLowerCase();
    // Use the already filtered items so maps and dropdown match filter settings
    final currentFilters = _getFilteredItems(_allItems);
    return currentFilters.where((item) {
      return item.title.toLowerCase().contains(lowerQuery) ||
             item.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 1. Google Map Layer
          _currentPosition == null
              ? const Center(child: FoundItLoadingIndicator())
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  mapType: _currentMapType,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 16.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

          // 2. Top Search Bar Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  final bool isSearchActive = value.text.isNotEmpty;
                  return Container(
                    clipBehavior: Clip.antiAlias, // Ensures internal components are clipped to borders
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search Bar
                        SizedBox(
                          height: 55,
                          child: TextField(
                            controller: _searchController,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: "Search items...",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 16,
                              ),
                              prefixIcon: const Icon(
                                PhosphorIconsRegular.magnifyingGlass,
                                color: Colors.grey,
                              ),
                              suffixIcon: isSearchActive
                                  ? IconButton(
                                      icon: const Icon(
                                        PhosphorIconsRegular.x,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        FocusScope.of(context).unfocus();
                                      },
                                    )
                                  : null,
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        if (isSearchActive) _buildSearchResultsDropdown(value.text),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: _MapSettingsMenuWidget(
          mapController: _mapController,
          currentMapType: _currentMapType,
          onMapTypeChanged: (newType) {
            setState(() {
              _currentMapType = newType;
              if (newType == MapType.normal) {
                _mapController?.setMapStyle(mapStyleJson);
              } else {
                _mapController?.setMapStyle(null);
              }
            });
          },
          onRecenter: _recenterToCurrentLocation,
          onFilter: _showFilterSettingsDialog,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // --- Map Settings & Filter Bottom Sheet ---
  void _showFilterSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Filter Items",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _buildFilterChip(
                        "Lost Items",
                        _showLost,
                        const Color(0xFFD32F2F),
                        (val) {
                          setSheetState(() => _showLost = val);
                          setState(() => _showLost = val);
                          _applyFiltersAndBuildMarkers();
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildFilterChip(
                        "Found Items",
                        _showFound,
                        const Color(0xFF388E3C),
                        (val) {
                          setSheetState(() => _showFound = val);
                          setState(() => _showFound = val);
                          _applyFiltersAndBuildMarkers();
                        },
                      ),
                    ],
                  ),
                  const Divider(
                    height: 40,
                    thickness: 1,
                    color: Colors.black12,
                  ),
                  const Text(
                    "Map Options",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Show Item Labels",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Display title below markers directly on map",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    activeColor: Theme.of(context).primaryColor,
                    value: _showLabels,
                    onChanged: (val) {
                      setSheetState(() => _showLabels = val);
                      setState(() => _showLabels = val);
                      _applyFiltersAndBuildMarkers();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultsDropdown(String query) {
    final results = _getSearchResults(query);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: results.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "No items found matching your search.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: results.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final item = results[index];
                final isLost = item.postType.toLowerCase() == 'lost';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLost
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLost
                          ? PhosphorIconsRegular.magnifyingGlass
                          : PhosphorIconsRegular.checkCircle,
                      color: isLost ? Colors.red : Colors.green,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    _showItemDetailsSheet(item);
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                );
              },
            ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    Color color,
    Function(bool) onSelected,
  ) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      backgroundColor: Colors.grey.shade100,
      selectedColor: color.withOpacity(0.15),
      checkmarkColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : Colors.transparent),
      ),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey.shade700,
        fontWeight: FontWeight.bold,
      ),
      onSelected: onSelected,
    );
  }

  // --- Bottom Sheet UI ---
  void _showItemDetailsSheet(ItemModel item) {
    if (_mapController != null &&
        _currentPosition != null &&
        item.location != null) {
      // Slightly pan the map to center the marker so the sheet doesn't cover it
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            item.location!.latitude - 0.003,
            item.location!.longitude,
          ), // offset shift
        ),
      );
    }

    final isLost = item.postType.toLowerCase() == 'lost';
    final typeColor = isLost
        ? const Color(0xFFD32F2F)
        : const Color(0xFF388E3C);

    // Calculate distance
    String distanceText = "Unknown distance";
    if (_currentPosition != null && item.location != null) {
      final double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        item.location!.latitude,
        item.location!.longitude,
      );
      if (distanceInMeters < 1000) {
        distanceText = "${distanceInMeters.toStringAsFixed(0)}m away";
      } else {
        distanceText = "${(distanceInMeters / 1000).toStringAsFixed(1)}km away";
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.1),
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          padding: const EdgeInsets.only(
            top: 12,
            left: 24,
            right: 24,
            bottom: 30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header Row (Type Badge + Title)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLost
                          ? PhosphorIconsRegular.magnifyingGlass
                          : PhosphorIconsRegular.checkCircle,
                      color: typeColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isLost ? 'LOST ITEM' : 'FOUND ITEM',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              distanceText,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Description Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemDetailsScreen(item: item),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B3B4F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "View Full Details",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapSettingsMenuWidget extends StatefulWidget {
  final GoogleMapController? mapController;
  final MapType currentMapType;
  final Function(MapType) onMapTypeChanged;
  final VoidCallback onRecenter;
  final VoidCallback onFilter;

  const _MapSettingsMenuWidget({
    required this.mapController,
    required this.currentMapType,
    required this.onMapTypeChanged,
    required this.onRecenter,
    required this.onFilter,
  });

  @override
  State<_MapSettingsMenuWidget> createState() => _MapSettingsMenuWidgetState();
}

class _MapSettingsMenuWidgetState extends State<_MapSettingsMenuWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_animationController.isCompleted) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: 'map_settings_fab',
      onTapOutside: (event) {
        if (_animationController.isCompleted ||
            _animationController.isAnimating) {
          _toggleMenu();
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final bool isOpen = _animationController.value > 0.0;
          return SizedBox(
            width: isOpen ? 160 : 56,
            height: isOpen ? 160 : 56,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomRight,
              children: [
                if (isOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleMenu,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                if (isOpen) ...[
                  Positioned(
                    right: 6, // center 44x44 aligned with 56x56
                    bottom: 6,
                    child: _buildAnimatedItem(
                      index: 0,
                      angle: 0.0, // Left
                      icon: PhosphorIconsRegular.funnel,
                      onTap: widget.onFilter,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _buildAnimatedItem(
                      index: 1,
                      angle: pi / 4, // Top-Left
                      icon: widget.currentMapType == MapType.normal
                          ? PhosphorIconsRegular.stack
                          : PhosphorIconsRegular.stack,
                      onTap: () {
                        widget.onMapTypeChanged(
                          widget.currentMapType == MapType.normal
                              ? MapType.satellite
                              : MapType.normal,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _buildAnimatedItem(
                      index: 2,
                      angle: pi / 2, // Top
                      icon: PhosphorIconsRegular.crosshair,
                      onTap: widget.onRecenter,
                    ),
                  ),
                ],
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _toggleMenu,
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.nightfall,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: RotationTransition(
                          turns: Tween<double>(
                            begin: 0.0,
                            end: 0.125,
                          ).animate(_animationController),
                          child: Icon(
                            _animationController.value > 0.5
                                ? PhosphorIconsRegular.plus
                                : PhosphorIconsRegular.gear,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedItem({
    required int index,
    required double angle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // slightly staggering the fan out
    final delayedValue = (_animationController.value * 1.5 - (index * 0.1))
        .clamp(0.0, 1.0);

    final radius = 80.0;
    // Moving to top-left relative to bottom-right button
    final dx = -radius * cos(angle) * delayedValue;
    final dy = -radius * sin(angle) * delayedValue;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: delayedValue,
        child: Opacity(
          opacity: delayedValue,
          child: _MapControlButton(icon: icon, onTap: onTap, size: 44),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: const Color(0xFF333345), size: size * 0.46),
        ),
      ),
    );
  }
}
