import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/item_model.dart';
import '../../../services/location_service.dart';
import '../../../widgets/found_it_loading_indicator.dart';
import '../../../core/constants/map_style.dart';
import '../../reports/item_details_screen.dart';

class AdminMapTab extends StatefulWidget {
  const AdminMapTab({super.key});

  @override
  State<AdminMapTab> createState() => _AdminMapTabState();
}

class _AdminMapTabState extends State<AdminMapTab> {
  bool _heatmapMode = false;
  MapType _currentMapType = MapType.normal;
  final LocationService _locationService = LocationService();
  
  GoogleMapController? _mapController;
  Position? _currentPosition;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(1.5533, 110.3592),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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
              zoom: 14.0,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  void _recenterToCurrentLocation() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 14.0,
        ),
      ),
    );
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentMapType == MapType.normal) {
      _mapController!.setMapStyle(mapStyleJson);
    }

    if (_currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  List<ItemModel> _filterItems(List<ItemModel> items) {
    return items.where((item) {
      if (item.location == null) return false;
      final status = item.status.toLowerCase();
      return item.postType.toLowerCase() == 'lost' && status != 'rejected';
    }).toList();
  }

  Set<Marker> _buildMarkers(List<ItemModel> items) {
    return items.map((item) {
      return Marker(
        markerId: MarkerId(item.itemId),
        position: LatLng(item.location!.latitude, item.location!.longitude),
        infoWindow: InfoWindow(
          title: item.title,
          snippet: item.specificLocation ?? item.locationName,
        ),
        onTap: () => _showItemDetailsSheet(item),
      );
    }).toSet();
  }

  void _showItemDetailsSheet(ItemModel item) {
    if (_mapController != null &&
        _currentPosition != null &&
        item.location != null) {
      // Keep marker visible above the sheet by slightly offsetting camera.
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(item.location!.latitude - 0.003, item.location!.longitude),
        ),
      );
    }

    final isLost = item.postType.toLowerCase() == 'lost';
    final typeColor = isLost ? const Color(0xFFD32F2F) : const Color(0xFF388E3C);

    String distanceText = 'Unknown distance';
    if (_currentPosition != null && item.location != null) {
      final double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        item.location!.latitude,
        item.location!.longitude,
      );
      if (distanceInMeters < 1000) {
        distanceText = '${distanceInMeters.toStringAsFixed(0)}m away';
      } else {
        distanceText = '${(distanceInMeters / 1000).toStringAsFixed(1)}km away';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.1),
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      'Description',
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
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemDetailsScreen(
                          item: item,
                          isAdminView: true,
                        ),
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
                    'View Full Details',
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

  Set<Circle> _buildHeatmapCircles(List<ItemModel> items) {
    final buckets = <String, List<ItemModel>>{};

    for (final item in items) {
      final lat = item.location!.latitude;
      final lng = item.location!.longitude;
      final key = '${(lat * 300).round()}_${(lng * 300).round()}';
      buckets.putIfAbsent(key, () => []).add(item);
    }

    final maxCount = buckets.values.fold<int>(
      0,
      (maxVal, list) => max(maxVal, list.length),
    );

    return buckets.entries.map((entry) {
      final cluster = entry.value;
      final centerLat =
          cluster.map((e) => e.location!.latitude).reduce((a, b) => a + b) /
          cluster.length;
      final centerLng =
          cluster.map((e) => e.location!.longitude).reduce((a, b) => a + b) /
          cluster.length;
      final ratio = maxCount == 0 ? 0.0 : cluster.length / maxCount;

      final fillColor =
          Color.lerp(
            Colors.yellow.withValues(alpha: 0.35),
            Colors.red.withValues(alpha: 0.65),
            ratio,
          ) ??
          Colors.orange;
      final strokeColor =
          Color.lerp(Colors.orange, Colors.red.shade900, ratio) ?? Colors.red;

      return Circle(
        circleId: CircleId('cluster_${entry.key}'),
        center: LatLng(centerLat, centerLng),
        radius: 120 + (ratio * 240),
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: 2,
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('items').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: FoundItLoadingIndicator());
              }

              final allItems = (snapshot.data?.docs ?? [])
                  .map(
                    (doc) => ItemModel.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .toList();
              final items = _filterItems(allItems);

              return GoogleMap(
                initialCameraPosition: _currentPosition != null
                    ? CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 14.0,
                      )
                    : _initialCamera,
                onMapCreated: _onMapCreated,
                mapType: _currentMapType,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: _heatmapMode ? {} : _buildMarkers(items),
                circles: _heatmapMode ? _buildHeatmapCircles(items) : {},
              );
            },
          ),
          // Mode Toggle Button (Regular/Heatmap)
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Row(
                children: [
                  _modeChip(
                    label: 'Regular',
                    selected: !_heatmapMode,
                    onTap: () => setState(() => _heatmapMode = false),
                  ),
                  const SizedBox(width: 8),
                  _modeChip(
                    label: 'Heatmap',
                    selected: _heatmapMode,
                    onTap: () => setState(() => _heatmapMode = true),
                  ),
                ],
              ),
            ),
          ),
          // Map controls (reachable): layer, recenter, zoom in, zoom out
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 110,
            right: 16,
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
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF333345) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF333345) : const Color(0xFFE2E2EA),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF333345),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MapSettingsMenuWidget extends StatefulWidget {
  final GoogleMapController? mapController;
  final MapType currentMapType;
  final Function(MapType) onMapTypeChanged;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _MapSettingsMenuWidget({
    required this.mapController,
    required this.currentMapType,
    required this.onMapTypeChanged,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _animationController.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _animationController.value) * 20),
                child: IgnorePointer(
                  ignoring: _animationController.value < 0.1,
                  child: Column(
                    children: [
                      _buildAnimatedItem(
                        index: 0,
                        dx: -6,
                        icon: widget.currentMapType == MapType.normal
                            ? Icons.layers_outlined
                            : Icons.layers,
                        onTap: () {
                          widget.onMapTypeChanged(
                            widget.currentMapType == MapType.normal
                                ? MapType.satellite
                                : MapType.normal,
                          );
                        },
                      ),
                      _buildAnimatedItem(
                        index: 1,
                        dx: -18,
                        icon: Icons.my_location,
                        onTap: widget.onRecenter,
                      ),
                      _buildAnimatedItem(
                        index: 2,
                        dx: -28,
                        icon: Icons.add,
                        onTap: widget.onZoomIn,
                      ),
                      _buildAnimatedItem(
                        index: 3,
                        dx: -20,
                        icon: Icons.remove,
                        onTap: widget.onZoomOut,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        _MapControlButton(
          icon: _animationController.isCompleted ? Icons.close : Icons.settings,
          onTap: _toggleMenu,
        ),
      ],
    );
  }

  Widget _buildAnimatedItem({
    required int index,
    required double dx,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final delayedValue = (_animationController.value * 4 - index).clamp(0.0, 1.0) as double;
    return Transform.translate(
      offset: Offset(dx * delayedValue, 0),
      child: Opacity(
        opacity: delayedValue,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MapControlButton(icon: icon, onTap: onTap),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: const Color(0xFF333345)),
        ),
      ),
    );
  }
}