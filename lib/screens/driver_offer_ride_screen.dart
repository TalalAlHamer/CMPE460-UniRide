import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'driver_ride_published_confirmation_screen.dart';
import 'driver_create_vehicle_screen.dart';
import 'package:uniride_app/services/secure_places_service.dart';

/// ------------ OFFER RIDE SCREEN ------------
class DriverOfferRideScreen extends StatefulWidget {
  const DriverOfferRideScreen({super.key});

  @override
  State<DriverOfferRideScreen> createState() => _DriverOfferRideScreenState();
}

class _DriverOfferRideScreenState extends State<DriverOfferRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _seats = TextEditingController();
  final _price = TextEditingController();

  final _focusFrom = FocusNode();
  final _focusTo = FocusNode();

  Timer? _debounce;
  List<LocationSuggestion> _results = [];
  String? _activeField;

  LatLng? fromPoint;
  LatLng? toPoint;
  double? distanceKm;
  int? durationMin;

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  String? selectedVehicleId;
  Map<String, dynamic>? selectedVehicleData;

  static const Color teal = Color(0xFF009DAE);
  static const Color yellow = Color(0xFFFFC727);
  static const Color screen = Color(0xFFE0F9FB);

  @override
  void initState() {
    super.initState();

    _focusFrom.addListener(() {
      if (_focusFrom.hasFocus) {
        _activeField = "from";
        if (_from.text.isNotEmpty) _search(_from.text);
      }
    });

    _focusTo.addListener(() {
      if (_focusTo.hasFocus) {
        _activeField = "to";
        if (_to.text.isNotEmpty) _search(_to.text);
      }
    });
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _date.dispose();
    _time.dispose();
    _seats.dispose();
    _price.dispose();
    _focusFrom.dispose();
    _focusTo.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ---------------- SEARCH ----------------
  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (value.trim().length < 3) {
        setState(() => _results = []);
        return;
      }

      final res = await SecurePlacesService.search(value);
      if (!mounted) return;

      setState(() => _results = res);
    });
  }

  void _select(LocationSuggestion s) {
    setState(() {
      if (_activeField == "from") {
        _from.text = s.displayName;
        fromPoint = LatLng(s.lat, s.lon);
      } else {
        _to.text = s.displayName;
        toPoint = LatLng(s.lat, s.lon);
      }
      _results = [];
    });

    _updateRouteInfo();
    FocusScope.of(context).unfocus();
  }

  // ---------------- MAP PICKER ----------------
  Future<void> _pickOnMap(
    TextEditingController controller,
    String field,
  ) async {
    LatLng? picked;
    LatLng defaultLoc = const LatLng(26.07, 50.55);

    final pos = await _getCurrentLoc();
    if (pos != null) defaultLoc = pos;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: picked ?? defaultLoc,
                      zoom: 13,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    padding: const EdgeInsets.only(bottom: 100),
                    markers: picked != null
                        ? {
                            Marker(
                              markerId: const MarkerId("m"),
                              position: picked!,
                            ),
                          }
                        : {},
                    onTap: (p) {
                      setSheet(() => picked = p);
                    },
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: picked == null
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              final addr = await SecurePlacesService.reverse(
                                picked!,
                              );

                              setState(() {
                                controller.text =
                                    addr ??
                                    "${picked!.latitude}, ${picked!.longitude}";
                                if (field == "from") fromPoint = picked;
                                if (field == "to") toPoint = picked;
                              });

                              _updateRouteInfo();
                              if (!mounted) return;
                              navigator.pop();
                            },
                      child: const Text(
                        "Confirm Location",
                        style: TextStyle(color: Colors.white, fontSize: 17),
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

  // ---------------- ROUTE INFO ----------------
  void _updateRouteInfo() {
    if (fromPoint == null || toPoint == null) {
      setState(() {
        distanceKm = null;
        durationMin = null;
      });
      return;
    }

    const R = 6371.0;
    double dLat = _toRad(toPoint!.latitude - fromPoint!.latitude);
    double dLon = _toRad(toPoint!.longitude - fromPoint!.longitude);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(fromPoint!.latitude)) *
            cos(_toRad(toPoint!.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double d = R * c;

    int minutes = (d / 45 * 60).round().clamp(1, 999);

    setState(() {
      distanceKm = d;
      durationMin = minutes;
    });
  }

  double _toRad(double deg) => deg * pi / 180;

  // ---------------- CURRENT LOCATION ----------------
  Future<LatLng?> _getCurrentLoc() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      msg("Please enable location services.");
      return null;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        msg("UniRide works best with your location enabled.");
        return null;
      }
    }

    if (perm == LocationPermission.deniedForever) {
      msg("Location permission permanently denied.");
      return null;
    }

    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return LatLng(p.latitude, p.longitude);
  }

  // ---------------- DATE PICKER ----------------
  void _openCalendar() {
    // Ensure selectedDate is not in the past
    final now = DateTime.now();
    final initialDate = selectedDate.isBefore(now) ? now : selectedDate;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SizedBox(
          height: 400,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                "Select a Date",
                style: TextStyle(
                  color: teal,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: teal),
                  ),
                  child: CalendarDatePicker(
                    initialDate: initialDate,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    onDateChanged: (d) {
                      setState(() {
                        selectedDate = d;
                        _date.text = "${d.day}/${d.month}/${d.year}";
                      });
                      Navigator.pop(context);
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

  // ---------------- TIME PICKER ----------------
  void _openTimePicker() {
    final hours = List.generate(12, (i) => i + 1);
    final minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));
    final ampm = ["AM", "PM"];

    int selectedHourIndex = 0;
    int selectedMinuteIndex = 0;
    int selectedAmpmIndex = selectedTime.period == DayPeriod.am ? 0 : 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SizedBox(
          height: 330,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                "Select Time",
                style: TextStyle(
                  color: teal,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (i) {
                          selectedHourIndex = i;
                        },
                        children: hours
                            .map((h) => Center(child: Text(h.toString())))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (i) {
                          selectedMinuteIndex = i;
                        },
                        children: minutes
                            .map((m) => Center(child: Text(m)))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (i) {
                          selectedAmpmIndex = i;
                        },
                        children: ampm
                            .map((p) => Center(child: Text(p)))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  int hour = hours[selectedHourIndex] % 12;
                  if (selectedAmpmIndex == 1) hour += 12;

                  final picked = TimeOfDay(
                    hour: hour,
                    minute: selectedMinuteIndex,
                  );

                  // Validate: time must be at least 15 minutes from now if date is today
                  final now = DateTime.now();
                  final todayStr = "${now.day}/${now.month}/${now.year}";
                  final isToday = _date.text == todayStr;

                  if (isToday) {
                    final nowMinutes = now.hour * 60 + now.minute;
                    final pickedMinutes = picked.hour * 60 + picked.minute;

                    if (pickedMinutes < nowMinutes + 15) {
                      Navigator.pop(context);
                      setState(() {
                        _time.clear(); // Clear the time field
                      });
                      msg(
                        "Please choose a valid time at least 15 minutes from now",
                      );
                      return;
                    }
                  }

                  setState(() {
                    selectedTime = picked;
                    _time.text =
                        "${hours[selectedHourIndex]}:${minutes[selectedMinuteIndex]} ${ampm[selectedAmpmIndex]}";
                  });

                  Navigator.pop(context);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    "Confirm",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ---------------- VEHICLE SELECTOR ----------------
  Future<void> _selectVehicle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      msg("Please log in to select a vehicle");
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('vehicles')
        .where('userId', isEqualTo: user.uid)
        .get();

    if (!mounted) return;

    if (snap.docs.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("No vehicles"),
          content: const Text(
            "You don't have any vehicles yet. Create one first.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverCreateVehicleScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: yellow),
              child: const Text(
                "Create vehicle",
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Vehicle"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: snap.docs.length,
            itemBuilder: (context, i) {
              final doc = snap.docs[i];
              final data = doc.data();

              return ListTile(
                leading: const Icon(Icons.directions_car, color: teal),
                title: Text("${data['year']} ${data['make']} ${data['model']}"),
                subtitle: Text("${data['color']} - ${data['licensePlate']}"),
                onTap: () {
                  setState(() {
                    selectedVehicleId = doc.id;
                    selectedVehicleData = data;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------- PUBLISH RIDE ----------------
  Future<void> _publishRide() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        msg("Please log in to publish a ride");
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: yellow)),
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profile = userDoc.data() ?? {};
      final phone = profile['phone'] ?? '';
      final userName = profile['name'] ?? user.displayName ?? 'UniRide User';

      final totalSeats = int.tryParse(_seats.text) ?? 1;
      final priceValue = double.tryParse(_price.text) ?? 0.0;


      final rideData = {
        'driverId': user.uid,
        'driverName': userName,
        'driverEmail': user.email ?? '',
        'driverPhone': phone,
        'from': _from.text,
        'to': _to.text,
        'fromLat': fromPoint?.latitude,
        'fromLng': fromPoint?.longitude,
        'toLat': toPoint?.latitude,
        'toLng': toPoint?.longitude,
        'date': _date.text,
        'time': _time.text,
        'seats': totalSeats, // total seats
        'seatsAvailable': totalSeats, // live available seats
        'price': priceValue,
        'distanceKm': distanceKm,
        'durationMinutes': durationMin,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'passengers': [],
        'vehicleId': selectedVehicleId,
        'vehicleMake': selectedVehicleData?['make'],
        'vehicleModel': selectedVehicleData?['model'],
        'vehicleYear': selectedVehicleData?['year'],
        'vehicleColor': selectedVehicleData?['color'],
        'vehicleLicensePlate': selectedVehicleData?['licensePlate'],
      };

      await FirebaseFirestore.instance
          .collection('rides')
          .add(rideData);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverRidePublishedConfirmationScreen(
              from: _from.text,
              to: _to.text,
              date: _date.text,
              time: _time.text,
              price: _price.text,
            ),
          ),
        );
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      if (mounted) Navigator.pop(context);
      msg("Error publishing ride: $e");
    }
  }

  // ---------------- FIELD HELPERS ----------------
  Widget _locationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FocusNode focusNode,
    required String fieldId,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        onChanged: (v) {
          _activeField = fieldId;
          _search(v);
        },
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: teal),
          suffixIcon: IconButton(
            icon: const Icon(Icons.map_outlined, color: teal),
            onPressed: () => _pickOnMap(controller, fieldId),
          ),
          labelText: "$label (search or pick on map)",
          labelStyle: const TextStyle(color: Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboard,
        onTap: onTap,
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: teal),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: screen,
      appBar: AppBar(
        backgroundColor: screen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: teal),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Offer a Ride",
          style: TextStyle(color: teal, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Share your ride with other UniRide students.",
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _locationField(
                        controller: _from,
                        label: "From",
                        icon: Icons.location_on_outlined,
                        focusNode: _focusFrom,
                        fieldId: "from",
                      ),
                      _locationField(
                        controller: _to,
                        label: "To",
                        icon: Icons.flag_outlined,
                        focusNode: _focusTo,
                        fieldId: "to",
                      ),

                      if (_results.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, i) {
                              final s = _results[i];
                              return ListTile(
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: teal,
                                ),
                                title: Text(s.displayName),
                                onTap: () => _select(s),
                              );
                            },
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemCount: _results.length,
                          ),
                        ),

                      if (distanceKm != null && durationMin != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Approx. ${distanceKm!.toStringAsFixed(1)} km • ~$durationMin min",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _date,
                              label: "Date",
                              icon: Icons.calendar_today,
                              readOnly: true,
                              onTap: _openCalendar,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: _time,
                              label: "Time",
                              icon: Icons.access_time,
                              readOnly: true,
                              onTap: _openTimePicker,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: TextFormField(
                                controller: _seats,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return "Required";
                                  final val = int.tryParse(v);
                                  if (val == null || val < 1) {
                                    return "Min 1 seat";
                                  }
                                  if (val > 10) return "Max 10 seats";
                                  return null;
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.event_seat,
                                    color: teal,
                                  ),
                                  labelText: "Seats",
                                  labelStyle: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: TextFormField(
                                controller: _price,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return "Required";
                                  final val = double.tryParse(v);
                                  if (val == null || val < 1) return "Min BD 1";
                                  if (val > 500) return "Max BD 500";
                                  return null;
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.attach_money,
                                    color: teal,
                                  ),
                                  labelText: "Price (BD)",
                                  labelStyle: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectVehicle,
                          icon: const Icon(Icons.directions_car),
                          label: Text(
                            selectedVehicleData != null
                                ? "${selectedVehicleData!['year']} ${selectedVehicleData!['make']} ${selectedVehicleData!['model']}"
                                : "Select Vehicle",
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedVehicleData == null
                                ? Colors.grey[400]
                                : teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Validate form first to show all error messages
                            final isValid = _formKey.currentState!.validate();
                            
                            // Then check vehicle selection
                            if (selectedVehicleId == null) {
                              msg("Please select a vehicle");
                              return;
                            }
                            
                            // Only publish if form is valid
                            if (isValid) {
                              _publishRide();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: yellow,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Publish Ride",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
