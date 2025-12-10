import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'driver_offer_ride_screen.dart';
import 'passenger_find_ride_screen.dart';
import 'rating_screen.dart';
import 'notifications_screen.dart';
import 'widgets/bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(26.0667, 50.5577); // Default Bahrain location
  LatLng? _userLocation;
  LatLng? _selectedPoint;
  bool _mapLoaded = false;
  StreamSubscription<QuerySnapshot>? _pendingRatingsListener;

  // UniRide Colors
  static const Color kUniRideTeal2 = Color(0xFF009DAE);
  static const Color kUniRideYellow = Color(0xFFFFC727);
  static const Color kScreenTeal = Color(0xFFE0F9FB);

  @override
  void initState() {
    super.initState();
    _loadUserLocation(); // Auto-center on startup
    _setupPendingRatingsListener(); // Set up real-time listener for pending ratings
  }

  @override
  void dispose() {
    _pendingRatingsListener?.cancel();
    super.dispose();
  }

  // -----------------------
  // PENDING RATINGS LISTENER
  // -----------------------
  void _setupPendingRatingsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen for new pending ratings in real-time
    _pendingRatingsListener = FirebaseFirestore.instance
        .collection('pending_ratings')
        .where('passengerId', isEqualTo: user.uid)
        .where('completed', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted && snapshot.docs.isNotEmpty) {
              final data = snapshot.docs.first.data();
              final docId = snapshot.docs.first.id;

              // Show rating screen modal
              _showRatingScreen(docId, data);
            }
          },
          onError: (e) {
          },
        );
  }

  Future<void> _showRatingScreen(
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RatingScreen(
            rideId: data['rideId'] ?? '',
            isDriver: false,
            usersToRate: [
              {
                'userId': data['driverId'] ?? '',
                'name': data['driverName'] ?? 'Driver',
              },
            ],
          ),
        ),
      );

      // Mark rating as completed if screen was completed
      if (result == true) {
        await FirebaseFirestore.instance
            .collection('pending_ratings')
            .doc(docId)
            .update({'completed': true});
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
  }

  // -----------------------
  // USER LOCATION LOADING
  // -----------------------
  Future<void> _loadUserLocation() async {
    bool allowed = await _handleLocationPermission(context);

    if (!allowed) {
      if (mounted) {
        setState(() => _mapLoaded = true);
      }
      return;
    }

    try {
      // Get current position with timeout
      Position pos =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () async {
              // If timeout, try with lower accuracy
              return await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                ),
              );
            },
          );

      if (!mounted) return;

      _userLocation = LatLng(pos.latitude, pos.longitude);


      setState(() {
        _center = _userLocation!;
        _mapLoaded = true;
      });

      // Auto move map to the user's location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _center, zoom: 14),
          ),
        );
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      if (mounted) {
        setState(() => _mapLoaded = true);
        _showMessage("Could not get your location. Using default location.");
      }
    }
  }

  Future<bool> _handleLocationPermission(BuildContext context) async {
    LocationPermission permission;

    if (!await Geolocator.isLocationServiceEnabled()) {
      _showMessage("Please enable location services.");
      return false;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        _showMessage("UniRide works best with your location enabled.");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage("Location permission permanently denied. Open Settings.");
      return false;
    }

    return true;
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -----------------------
  // REVERSE GEOCODING
  // -----------------------
  Future<String?> _getAddressFromLatLng(LatLng position) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${position.latitude}'
        '&lon=${position.longitude}'
        '&format=json'
        '&addressdetails=1'
        '&accept-language=en',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'uniride_app/1.0 (student project; contact: example@uniride.app)',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          String? place =
              address['road'] ?? address['neighbourhood'] ?? address['suburb'];
          String? city =
              address['city'] ?? address['town'] ?? address['village'];

          final parts = <String>[
            if (place != null && place.isNotEmpty) place,
            if (city != null && city.isNotEmpty) city,
          ];

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        return data['display_name'] as String?;
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
    return null;
  }

  // -----------------------
  // UI
  // -----------------------
  Future<void> _refreshScreen() async {
    // Reload user location
    await _loadUserLocation();
    // Brief delay for smooth animation
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kScreenTeal,
      appBar: AppBar(
        backgroundColor: kScreenTeal,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          "UniRide",
          style: TextStyle(
            color: kUniRideTeal2,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: user.uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data?.docs.length ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications,
                        color: kUniRideTeal2,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshScreen,
          color: kUniRideTeal2,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 25),

                // MAP CARD
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          //! THE MAP
                          SizedBox(
                            height: 280,
                            width: double.infinity,
                            child: !_mapLoaded
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : GoogleMap(
                                    onMapCreated: (controller) {
                                      _mapController = controller;
                                      // Move camera to user location after map is created
                                      if (_userLocation != null) {
                                        controller.animateCamera(
                                          CameraUpdate.newCameraPosition(
                                            CameraPosition(
                                              target: _userLocation!,
                                              zoom: 14,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    initialCameraPosition: CameraPosition(
                                      target: _center,
                                      zoom: 13,
                                    ),
                                    onTap: (LatLng position) {
                                      setState(() {
                                        _selectedPoint = position;
                                      });
                                      _showMessage("Pickup location selected on map");
                                    },
                                    markers: _selectedPoint == null
                                        ? {}
                                        : {
                                            Marker(
                                              markerId: const MarkerId('selected'),
                                              position: _selectedPoint!,
                                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                                BitmapDescriptor.hueRed,
                                              ),
                                              infoWindow: const InfoWindow(
                                                title: 'Selected Pickup Location',
                                              ),
                                            ),
                                          },
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    myLocationEnabled: true,
                                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                                      Factory<OneSequenceGestureRecognizer>(
                                        () => EagerGestureRecognizer(),
                                      ),
                                    },
                                  ),
                          ),

                          // ⭐ CENTER MY LOCATION BUTTON
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: FloatingActionButton(
                              mini: true,
                              backgroundColor: Colors.white,
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                if (_userLocation != null &&
                                    _mapController != null) {
                                  _mapController!.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(
                                        target: _userLocation!,
                                        zoom: 14,
                                      ),
                                    ),
                                  );
                                } else {
                                  _showMessage("Location not available.");
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  "Where do you want to go?",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: kUniRideTeal2,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Choose an option to get started",
                  style: TextStyle(color: Colors.black54, fontSize: 15),
                ),

                const SizedBox(height: 32),

                // OFFER RIDE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverOfferRideScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kUniRideYellow,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      "Offer a Ride",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // FIND RIDE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      // If user selected a point on the map, get its address
                      String? address;
                      if (_selectedPoint != null) {
                        try {
                          address = await _getAddressFromLatLng(
                            _selectedPoint!,
                          );
                        } catch (e) {
    // Error handling: silently catch to prevent crashes
                          // Fallback to coordinates if reverse geocoding fails
                          address =
                              "${_selectedPoint!.latitude.toStringAsFixed(4)}, ${_selectedPoint!.longitude.toStringAsFixed(4)}";
                        }
                      }

                      if (!mounted) return;

                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => PassengerFindRideScreen(
                            initialPickupLocation: _selectedPoint,
                            initialPickupAddress: address,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: kUniRideTeal2, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      "Find a Ride",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kUniRideTeal2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}
