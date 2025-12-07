import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'passenger_ride_details_screen.dart';
import 'package:uniride_app/services/rating_service.dart';
import 'package:uniride_app/services/secure_places_service.dart';

// ------------------------------------------------------

class PassengerFindRideScreen extends StatefulWidget {
  final LatLng? initialPickupLocation;
  final String? initialPickupAddress;

  const PassengerFindRideScreen({
    super.key,
    this.initialPickupLocation,
    this.initialPickupAddress,
  });

  @override
  State<PassengerFindRideScreen> createState() => _PassengerFindRideScreenState();
}

class _PassengerFindRideScreenState extends State<PassengerFindRideScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  final FocusNode _pickupFocusNode = FocusNode();

  TimeOfDay? startTime;
  TimeOfDay? endTime;

  Timer? _debounce;
  List<LocationSuggestion> _suggestions = [];
  bool _isSearchingLocations = false;

  LatLng? _pickupLocation;
  LatLng? _currentUserLocation; // For automatic filtering
  static const double _searchRadiusKm = 10.0;

  static const Color kScreenTeal = Color(0xFFE0F9FB);
  static const Color kUniRideTeal2 = Color(0xFF009DAE);

  @override
  void initState() {
    super.initState();

    if (widget.initialPickupLocation != null) {
      _pickupLocation = widget.initialPickupLocation;
      if (widget.initialPickupAddress != null) {
        _pickupController.text = widget.initialPickupAddress!;
      }
    }

    // Get user's current location for automatic filtering
    _getUserLocation();

    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus &&
          _pickupController.text.trim().length >= 3) {
        _onPickupChanged(_pickupController.text);
      }
    });
  }

  // Get user's current location
  Future<void> _getUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dateController.dispose();
    _pickupFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------------- DISTANCE CALCULATION ----------------
  double _toRad(double degree) => degree * (pi / 180);

  double _calculateDistance(LatLng p1, LatLng p2) {
    const R = 6371;
    final dLat = _toRad(p2.latitude - p1.latitude);
    final dLon = _toRad(p2.longitude - p1.longitude);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(p1.latitude)) *
            cos(_toRad(p2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  bool _isWithinRadius(LatLng center, LatLng point) {
    return _calculateDistance(center, point) <= _searchRadiusKm;
  }

  // ---------------- AUTOCOMPLETE ----------------
  void _onPickupChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.trim().length < 3) {
        setState(() => _suggestions = []);
        return;
      }

      setState(() => _isSearchingLocations = true);

      final results = await SecurePlacesService.search(value);

      if (!mounted) return;

      setState(() {
        _suggestions = results;
        _isSearchingLocations = false;
      });
    });
  }

  void _selectSuggestion(LocationSuggestion suggestion) {
    setState(() {
      _pickupController.text = suggestion.displayName;
      _pickupLocation = LatLng(suggestion.lat, suggestion.lon);
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  // ---------------- MAP PICKER (WITH FIX) ----------------
  Future<void> _openPickupMapPicker() async {
    LatLng? selectedPoint;

    LatLng initialCenter = const LatLng(26.0667, 50.5577);
    final current = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    initialCenter = LatLng(current.latitude, current.longitude);
    selectedPoint = initialCenter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setStateSheet) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialCenter,
                      zoom: 13,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    padding: const EdgeInsets.only(bottom: 100),

                    // ⭐ Allow dragging/panning in bottom sheet
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },

                    markers: selectedPoint != null
                        ? {
                            Marker(
                              markerId: const MarkerId('selected'),
                              position: selectedPoint!,
                            ),
                          }
                        : {},

                    onTap: (LatLng point) {
                      setStateSheet(() => selectedPoint = point);
                    },
                  ),

                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kUniRideTeal2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: selectedPoint == null
                          ? null
                          : () async {
                              final address =
                                  await SecurePlacesService.reverse(
                                    selectedPoint!,
                                  );

                              setState(() {
                                _pickupController.text =
                                    address ??
                                    "${selectedPoint!.latitude}, ${selectedPoint!.longitude}";
                                _pickupLocation = selectedPoint;
                                _suggestions = [];
                              });

                              Navigator.of(sheetContext).pop();
                            },
                      child: const Text(
                        "Confirm Pickup Location",
                        style: TextStyle(
                          fontSize: 18,
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
      },
    );
  }

  // ---------------- CALENDAR ----------------
  void _openCalendar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            children: [
              const Text(
                "Select a Date",
                style: TextStyle(
                  color: kUniRideTeal2,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: kUniRideTeal2),
                  ),
                  child: CalendarDatePicker(
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                    onDateChanged: (picked) {
                      _dateController.text =
                          "${picked.day}/${picked.month}/${picked.year}";
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- TIME PICKER (WITH FIX) ----------------
  void _openTimePicker({required bool isStart}) {
    List<int> availableHours = [];
    List<int> availableMinutes = [];
    List<int> availableAmPm = [];

    // For start time, show all times
    if (isStart) {
      availableHours = List.generate(12, (i) => i + 1);
      availableMinutes = List.generate(60, (i) => i);
      availableAmPm = [0, 1]; // AM and PM
    } else {
      // For end time, only show times at least 1 hour after start time
      if (startTime != null) {
        final startMinutes = startTime!.hour * 60 + startTime!.minute;
        final minEndMinutes = startMinutes + 60; // 1 hour minimum gap

        // Generate all possible times and filter valid ones
        for (int amPm = 0; amPm < 2; amPm++) {
          for (int h = 1; h <= 12; h++) {
            int hour24 = h % 12;
            if (amPm == 1) hour24 += 12;

            for (int m = 0; m < 60; m++) {
              final totalMinutes = hour24 * 60 + m;
              if (totalMinutes >= minEndMinutes) {
                if (!availableAmPm.contains(amPm)) availableAmPm.add(amPm);
                if (!availableHours.contains(h)) availableHours.add(h);
                if (!availableMinutes.contains(m)) availableMinutes.add(m);
              }
            }
          }
        }

        availableHours.sort();
        availableMinutes.sort();
      } else {
        // No start time set, show all times
        availableHours = List.generate(12, (i) => i + 1);
        availableMinutes = List.generate(60, (i) => i);
        availableAmPm = [0, 1];
      }
    }

    final hours = availableHours;
    final minutes = availableMinutes.map((m) => m.toString().padLeft(2, "0")).toList();
    final ampm = availableAmPm.map((ap) => ap == 0 ? "AM" : "PM").toList();

    int selectedHour = 0;
    int selectedMinute = 0;
    int selectedAmPm = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 330,
          child: Column(
            children: [
              Text(
                isStart ? "Select Start Time" : "Select End Time",
                style: const TextStyle(
                  color: kUniRideTeal2,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (i) => selectedHour = i,
                        children: hours
                            .map((h) => Center(child: Text(h.toString())))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (i) => selectedMinute = i,
                        children: minutes
                            .map((m) => Center(child: Text(m)))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (i) => selectedAmPm = i,
                        children: ampm
                            .map((p) => Center(child: Text(p)))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kUniRideTeal2,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  int hour = hours[selectedHour] % 12;
                  if (availableAmPm[selectedAmPm] == 1) hour += 12;

                  final picked = TimeOfDay(hour: hour, minute: availableMinutes[selectedMinute]);

                  setState(() {
                    if (isStart) {
                      startTime = picked;

                      // If end time exists, check if it's at least 1 hour after new start time
                      if (endTime != null) {
                        final startMinutes = startTime!.hour * 60 + startTime!.minute;
                        final endMinutes = endTime!.hour * 60 + endTime!.minute;
                        if (endMinutes < startMinutes + 60) {
                          endTime = null;
                        }
                      }
                    } else {
                      endTime = picked;
                    }
                  });

                  Navigator.of(sheetContext).pop();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  child: Text(
                    "Confirm",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return "--:--";
    return time.format(context);
  }

  // ---------------- UI WIDGETS + FIREBASE LISTENERS ----------------
  Widget _buildLocationSuggestions() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.black12),
        itemBuilder: (context, i) {
          final s = _suggestions[i];
          return ListTile(
            leading: const Icon(
              Icons.location_on_outlined,
              color: kUniRideTeal2,
            ),
            title: Text(
              s.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectSuggestion(s),
          );
        },
      ),
    );
  }

  // ---------------- MAIN BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScreenTeal,

      appBar: AppBar(
        backgroundColor: kScreenTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kUniRideTeal2,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Find a Ride",
          style: TextStyle(
            color: kUniRideTeal2,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter your details to search for available rides.",
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 20),

              _pickupField(),
              if (_isSearchingLocations)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              _buildLocationSuggestions(),
              
              const SizedBox(height: 16),

              GestureDetector(
                onTap: _openCalendar,
                child: AbsorbPointer(
                  child: _inputField(
                    controller: _dateController,
                    icon: Icons.calendar_today_outlined,
                    hint: "Date (dd/mm/yyyy)",
                  ),
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => _openTimePicker(isStart: true),
                child: _timeField(
                  label: "Start Time (rides after this time)",
                  value: _formatTime(startTime),
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => _openTimePicker(isStart: false),
                child: _timeField(
                  label: "End Time (rides before this time)",
                  value: _formatTime(endTime),
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Available Rides",
                    style: TextStyle(
                      color: kUniRideTeal2,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_pickupLocation != null)
                    Text(
                      "Within ${_searchRadiusKm.toStringAsFixed(0)}km",
                      style: TextStyle(
                        color: kUniRideTeal2.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rides')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(color: kUniRideTeal2),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 60,
                              color: Colors.black26,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No rides available",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allRides = snapshot.data!.docs;
                  
                  // Determine what search parameters user has entered
                  final hasLocation = _pickupLocation != null && _pickupController.text.trim().isNotEmpty;
                  final hasDate = _dateController.text.trim().isNotEmpty;
                  final hasStartTime = startTime != null;
                  final hasEndTime = endTime != null;
                  final hasAnyFilter = hasLocation || hasDate || hasStartTime || hasEndTime;
                  
                  // Filter rides based on search criteria
                  final filtered = allRides.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final lat = d['fromLat'];
                    final lng = d['fromLng'];
                    final rideDate = d['date'] ?? '';
                    final rideTime = d['time'] ?? '';
                    
                    // LOCATION FILTERING
                    bool passesLocationFilter = true;
                    if (hasLocation) {
                      // User specified location: check if ride is from that location
                      if (lat != null && lng != null) {
                        passesLocationFilter = _isWithinRadius(
                          _pickupLocation!,
                          LatLng(lat, lng),
                        );
                      } else {
                        passesLocationFilter = false;
                      }
                    } else if (!hasAnyFilter) {
                      // No filters at all: default to within 10km from user's current location
                      if (_currentUserLocation != null && lat != null && lng != null) {
                        passesLocationFilter = _isWithinRadius(
                          _currentUserLocation!,
                          LatLng(lat, lng),
                        );
                      } else {
                        passesLocationFilter = false;
                      }
                    }
                    // If user has date/time but no location: show all locations
                    
                    // DATE FILTERING
                    bool passesDateFilter = true;
                    if (hasDate) {
                      // User specified date: only show rides on that exact date
                      passesDateFilter = rideDate == _dateController.text.trim();
                    } else if (!hasAnyFilter) {
                      // No filters at all: default to today and future dates
                      final now = DateTime.now();
                      
                      // Parse ride date
                      final rideDateParts = rideDate.split('/');
                      if (rideDateParts.length == 3) {
                        final rideDay = int.tryParse(rideDateParts[0]);
                        final rideMonth = int.tryParse(rideDateParts[1]);
                        final rideYear = int.tryParse(rideDateParts[2]);
                        
                        if (rideDay != null && rideMonth != null && rideYear != null) {
                          final rideDateTime = DateTime(rideYear, rideMonth, rideDay);
                          final today = DateTime(now.year, now.month, now.day);
                          passesDateFilter = !rideDateTime.isBefore(today);
                        }
                      }
                    }
                    // If has location/time but no date: show rides for any date
                    
                    // TIME FILTERING
                    bool passesTimeFilter = true;
                    if (hasStartTime || hasEndTime) {
                      // Parse ride time (format: "HH:MM AM/PM")
                      final rideTimeOfDay = _parseTimeString(rideTime);
                      if (rideTimeOfDay != null) {
                        final rideMinutes = rideTimeOfDay.hour * 60 + rideTimeOfDay.minute;
                        
                        if (hasStartTime) {
                          final startMinutes = startTime!.hour * 60 + startTime!.minute;
                          if (rideMinutes < startMinutes) {
                            passesTimeFilter = false;
                          }
                        }
                        
                        if (hasEndTime && passesTimeFilter) {
                          final endMinutes = endTime!.hour * 60 + endTime!.minute;
                          if (rideMinutes > endMinutes) {
                            passesTimeFilter = false;
                          }
                        }
                      } else {
                        passesTimeFilter = false;
                      }
                    }
                    
                    return passesLocationFilter && passesDateFilter && passesTimeFilter;
                  }).toList();

                  return Column(
                    children: filtered.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _rideCard(
                          rideId: doc.id,
                          name: d['driverName'] ?? "Driver",
                          pickup: d['from'] ?? "",
                          destination: d['to'] ?? "",
                          time: d['time'] ?? "",
                          seats: "${d['seatsAvailable'] ?? 0} seats",
                          price: "BD ${d['price'] ?? '0.0'}",
                          data: d,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),


    );
  }

  // ---------------- INPUT WIDGETS ----------------
  Widget _pickupField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kUniRideTeal2.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _pickupController,
        focusNode: _pickupFocusNode,
        onChanged: _onPickupChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.location_on_outlined,
            color: kUniRideTeal2,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.map_outlined, color: kUniRideTeal2),
            onPressed: _openPickupMapPicker,
          ),
          hintText: "Pickup location (search or pick on map)",
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kUniRideTeal2.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kUniRideTeal2),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _timeField({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kUniRideTeal2.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 15),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ---------------- RIDE CARD ----------------
  Widget _rideCard({
    required String rideId,
    required String name,
    required String pickup,
    required String destination,
    required String time,
    required String seats,
    required String price,
    required Map<String, dynamic> data,
  }) {
    final driverId = data['driverId'] ?? "";

    // Read REAL seatsAvailable
    final int seatsAvailable = data['seatsAvailable'] is int
        ? data['seatsAvailable']
        : int.tryParse("${data['seatsAvailable']}") ?? 0;

    final bool isFull = seatsAvailable <= 0;

    return GestureDetector(
      onTap: () {
        // Option C: allow open, but notify if full
        if (isFull) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "This ride is currently full. You can still view details.",
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PassengerRideDetailsScreen(rideId: rideId, rideData: data),
          ),
        );
      },
      child: Opacity(
        opacity: isFull ? 0.7 : 1.0, // slightly dim when FULL
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver info row
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: kUniRideTeal2,
                    child: Text(
                      name.isNotEmpty ? name[0] : "?",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Rating badge
                  FutureBuilder<double>(
                    future: RatingService.getAverageRating(driverId),
                    builder: (context, snap) {
                      final r = snap.data ?? 0.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: r > 0
                              ? Colors.orange.shade300
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              r > 0 ? r.toStringAsFixed(1) : "—",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Seats available badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFull
                          ? Colors.red.shade400
                          : Colors.green.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isFull ? "FULL" : "$seatsAvailable left",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Pickup location with icon
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 20,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickup,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Destination with icon
              Row(
                children: [
                  const Icon(
                    Icons.flag,
                    size: 20,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destination,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Date, time, and price row with icons (no date passed here, so only time and price)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kUniRideTeal2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper function to parse time strings from Firestore (e.g., "10:30 AM" or "2:45 PM")
  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length != 2) return null;
      
      final timePart = parts[0]; // "10:30"
      final period = parts[1].toUpperCase(); // "AM" or "PM"
      
      final timeParts = timePart.split(':');
      if (timeParts.length != 2) return null;
      
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Convert to 24-hour format
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }
}
