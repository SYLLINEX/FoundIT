import 'dart:io';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/ai_service.dart';
import '../../models/item_model.dart';
import '../home/main_wrapper.dart'; // To Pop back to home
import 'match_results_screen.dart';
import '../../widgets/found_it_loading_indicator.dart';

class TagLocationScreen extends StatefulWidget {
  final String reportType;
  final String title;
  final String description;
  final String category;
  final DateTime date;
  final File? imageFile;
  final List<String> aiLabels;
  final List<double> aiScoreVector;

  const TagLocationScreen({
    super.key,
    required this.reportType,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    this.imageFile,
    this.aiLabels = const [],
    this.aiScoreVector = const [],
  });

  @override
  State<TagLocationScreen> createState() => _TagLocationScreenState();
}

class _TagLocationScreenState extends State<TagLocationScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isSubmitting = false;
  final TextEditingController _specificLocationController =
      TextEditingController();

  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final AIService _aiService = AIService();
  final _primaryDark = const Color(0xFF3B394D);

  String get _normalizedPostType {
    return widget.reportType.toLowerCase() == 'lost' ? 'Lost' : 'Found';
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _specificLocationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });
  }

  /// Queries all active Found items within 5 km and scores them against
  /// the new report using the same 5-signal AIService weights (visual cosine,
  /// labels, text, category, location). Items scoring >= 70 are returned
  /// sorted by score descending.
  Future<List<Map<String, dynamic>>> _findSimilarItems(
    GeoPoint userLocation,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('post_type', isEqualTo: 'Found')
        .get();

    // Build a synthetic ItemModel for the new report so AIService can compare.
    final newReport = ItemModel(
      itemId: '',
      userId: '',
      postType: 'Lost',
      category: widget.category,
      title: widget.title,
      description: widget.description,
      imageUrl: '',
      locationName: '',
      location: userLocation,
      status: 'Pending for Approval',
      aiLabels: widget.aiLabels,
      aiScoreVector: widget.aiScoreVector,
      timestamp: DateTime.now(),
    );

    List<Map<String, dynamic>> finalMatches = [];

    for (var doc in snapshot.docs) {
      final foundItem = ItemModel.fromMap(doc.id, doc.data());
      final status = foundItem.status.toLowerCase();
      if (status != 'open' && status != 'active' && status != 'reserved') {
        continue;
      }
      if (foundItem.location == null) continue;

      // Gate: skip items further than 5 km (AIService's max distance).
      final distanceInMeters = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        foundItem.location!.latitude,
        foundItem.location!.longitude,
      );
      if (distanceInMeters > AIService.maxDistanceForScoreMeters) continue;

      final score = _aiService.compareLostReportToClaim(
        linkedLostReport: newReport,
        claimTargetItem: foundItem,
        claimDescription: '',
      );

      if (score >= 70.0) {
        finalMatches.add({
          'item': foundItem,
          'distance': distanceInMeters,
          'score': score,
        });
      }
    }

    finalMatches.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    return finalMatches;
  }

  Future<void> _submitReport() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location on the map')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      String reporterName = user.displayName ?? 'Unknown User';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          reporterName = userDoc.data()?['username'] ?? reporterName;
        }
      } catch (_) {}

      String imageUrl = '';
      if (widget.imageFile != null) {
        imageUrl = await _storageService.uploadItemImage(
          widget.imageFile!,
          user.uid,
        );
      }

      final item = ItemModel(
        itemId: '',
        userId: user.uid,
        postType: _normalizedPostType,
        category: widget.category,
        title: widget.title,
        description: widget.description,
        imageUrl: imageUrl,
        locationName: 'Tagged Location',
        specificLocation: _specificLocationController.text.trim(),
        reporterName: reporterName,
        location: GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        status: 'Pending for Approval',
        aiLabels: widget.aiLabels,
        aiScoreVector: widget.aiScoreVector,
        timestamp: DateTime.now(),
      );

      final createdItemId = await _databaseService.addItem(item);

      await _notificationService.notifyAdmins(
        title: 'New report pending approval',
        body:
            '$_normalizedPostType report "${widget.title}" was submitted and is waiting for review.',
        type: 'admin_alert',
        relatedItemId: createdItemId,
        data: {'post_type': _normalizedPostType, 'category': widget.category},
      );

      if (mounted) {
        if (widget.reportType.toLowerCase() == 'lost') {
          // Trigger Matchmaking Logic
          final userLocation = GeoPoint(
            _selectedLocation!.latitude,
            _selectedLocation!.longitude,
          );
          final allMatchesInfo = await _findSimilarItems(userLocation);

          // Filter to only matches > 70% (aligned with AIService min threshold)
          final matchesInfo = allMatchesInfo
              .where((m) => (m['score'] as double) >= 70.0)
              .toList();

          if (matchesInfo.isNotEmpty) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => MatchResultsScreen(
                  matches: matchesInfo
                      .map((m) => m['item'] as ItemModel)
                      .toList(),
                  distances: matchesInfo
                      .map((m) => m['distance'] as double)
                      .toList(),
                  scores: matchesInfo.map((m) => m['score'] as double).toList(),
                  createdLostReportId: createdItemId,
                ),
              ),
              (Route<dynamic> route) => false,
            );
            return;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report submitted. It is now pending admin approval.',
            ),
          ),
        );
        // Pop all the way back to main wrapper
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainWrapper()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit report: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tag Location',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _primaryDark,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsRegular.caretLeft,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _isLoading
                        ? const Center(child: FoundItLoadingIndicator())
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _currentPosition != null
                                  ? LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    )
                                  : const LatLng(0, 0), // fallback location
                              zoom: 16,
                            ),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            onMapCreated: (controller) =>
                                _mapController = controller,
                            onTap: (LatLng location) {
                              setState(() {
                                _selectedLocation = location;
                              });
                            },
                            markers: _selectedLocation != null
                                ? {
                                    Marker(
                                      markerId: const MarkerId('selected_loc'),
                                      position: _selectedLocation!,
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            widget.reportType.toLowerCase() ==
                                                    'lost'
                                                ? BitmapDescriptor.hueRed
                                                : BitmapDescriptor.hueBlue,
                                          ),
                                    ),
                                  }
                                : {},
                          ),
                    if (_isLoading == false)
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(PhosphorIconsRegular.info, color: Colors.blue),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tap on the map to place a pin where the item was lost/found.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _specificLocationController,
                        decoration: InputDecoration(
                          labelText: 'Specific Location (Optional)',
                          hintText: 'e.g., Near the library fountain',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: _isSubmitting ? null : _submitReport,
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isSubmitting) const FunnyLoadingOverlay(),
        ],
      ),
    );
  }
}

class FunnyLoadingOverlay extends StatefulWidget {
  const FunnyLoadingOverlay({super.key});

  @override
  State<FunnyLoadingOverlay> createState() => _FunnyLoadingOverlayState();
}

class _FunnyLoadingOverlayState extends State<FunnyLoadingOverlay> {
  final List<String> _funnyMessages = [
    "Making reports...",
    "Asking Santa Claus...",
    "Interrogating local squirrels...",
    "Consulting the crystal ball...",
  ];
  int _currentIndex = 0;
  bool _timerActive = true;

  @override
  void initState() {
    super.initState();
    _startMessageCycle();
  }

  void _startMessageCycle() async {
    while (_timerActive && mounted) {
      await Future.delayed(const Duration(milliseconds: 3000));
      if (_timerActive && mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _funnyMessages.length;
        });
      }
    }
  }

  @override
  void dispose() {
    _timerActive = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FoundItLoadingIndicator(size: 36, color: Colors.white),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                _funnyMessages[_currentIndex],
                key: ValueKey<int>(_currentIndex),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
