import 'dart:async';
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
  String _searchQuery = "";
  bool _showLost = true;
  bool _showFound = true;
  bool _showLabels = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();

    // Add listener to rebuild when search text changes
    _searchController.addListener(() {
      _applyFiltersAndBuildMarkers();
    });
  }

  void _subscribeToNearbyItems(Position position) {
    _itemsSubscription?.cancel();

    _itemsSubscription = _databaseService
        .getItemsWithinRadiusStream(
          GeoPoint(position.latitude, position.longitude),
          radiusInKm: 1.0, // 1km Radius Proximity Search Feature
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
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    }
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

      // Automatically fetch items within 1km radius
      _subscribeToNearbyItems(position);
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
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
      // 1. Text Search Filter
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery) ||
          item.description.toLowerCase().contains(_searchQuery);

      // 2. Type Filter (Lost/Found)
      bool matchesType = false;
      if (item.postType.toLowerCase() == 'lost' && _showLost)
        matchesType = true;
      if (item.postType.toLowerCase() == 'found' && _showFound)
        matchesType = true;

      return matchesSearch && matchesType;
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
              child: Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: Container(
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search items...",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 17,
                          ), // centers the text aligning with icon
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Filter Button
                  _buildIconButton(
                    Icons.filter_alt_outlined,
                    _showFilterSettingsDialog,
                  ),
                ],
              ),
            ),
          ),

          // 2.5 Map Type Toggle Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80, right: 20, left: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Map Layer Toggle
                  _buildIconButton(
                    _currentMapType == MapType.normal
                        ? Icons.layers_outlined
                        : Icons.layers,
                    () {
                      setState(() {
                        _currentMapType = _currentMapType == MapType.normal
                            ? MapType.satellite
                            : MapType.normal;

                        if (_currentMapType == MapType.normal) {
                          _mapController?.setMapStyle(mapStyleJson);
                        } else {
                          _mapController?.setMapStyle(null);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                      isLost ? Icons.search : Icons.check_circle_outline,
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

  // Helper widget for top bar buttons
  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      height: 55,
      width: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onTap,
      ),
    );
  }
}
