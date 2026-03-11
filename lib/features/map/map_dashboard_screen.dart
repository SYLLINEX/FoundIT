import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/item_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../core/constants/map_style.dart';

class MapDashboardScreen extends StatefulWidget {
  const MapDashboardScreen({super.key});

  @override
  State<MapDashboardScreen> createState() => _MapDashboardScreenState();
}

class _MapDashboardScreenState extends State<MapDashboardScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
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
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  void _updateMarkers(List<ItemModel> items) {
    Set<Marker> newMarkers = items.map((item) {
      final isLost = item.type == 'lost';
      return Marker(
        markerId: MarkerId(item.id),
        position: LatLng(item.location.latitude, item.location.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isLost ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: item.title,
          snippet: item.description,
        ),
      );
    }).toSet();

    if (_markers.length != newMarkers.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _markers = newMarkers;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: StreamBuilder<List<ItemModel>>(
        stream: _databaseService.getItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _updateMarkers(snapshot.data!);
          }

          return Stack(
            children: [
              // 1. Google Map Layer
              _currentPosition == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      onMapCreated: _onMapCreated,
                      mapType: _currentMapType,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
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
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 15),
                              const Icon(Icons.search, color: Colors.grey),
                              const SizedBox(width: 10),
                              Text(
                                "Search within 1km...",
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Filter Button
                      _buildIconButton(Icons.filter_alt_outlined, () {}),
                    ],
                  ),
                ),
              ),

              // 2.5 Map Type Toggle Button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 80, right: 20),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: _buildIconButton(
                      _currentMapType == MapType.normal ? Icons.layers_outlined : Icons.layers, 
                      () {
                        setState(() {
                          _currentMapType = _currentMapType == MapType.normal 
                              ? MapType.satellite 
                              : MapType.normal;
                          
                          // Google Maps allows applying JSON styles only on MapType.normal
                          if (_currentMapType == MapType.normal) {
                            _mapController?.setMapStyle(mapStyleJson);
                          } else {
                            _mapController?.setMapStyle(null); // Clear style for satellite
                          }
                        });
                      }
                    ),
                  ),
                ),
              ),

              // 3. Floating Filter Status Card
              Positioned(
                // Position above the global MainWrapper CustomBottomNavBar
                bottom: 110, 
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Map Filters Active",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.circle, color: Color(0xFFD32F2F), size: 12),
                          const SizedBox(width: 6),
                          Text("Lost", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 20),
                          const Icon(Icons.circle, color: Color(0xFF388E3C), size: 12),
                          const SizedBox(width: 6),
                          Text("Found", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onTap,
      ),
    );
  }
}
