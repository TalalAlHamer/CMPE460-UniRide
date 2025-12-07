import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'passenger_request_confirmation_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'chat_screen.dart';
import '../services/chat_service.dart';

class PassengerRideDetailsScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const PassengerRideDetailsScreen({
    super.key,
    required this.rideId,
    required this.rideData,
  });

  @override
  State<PassengerRideDetailsScreen> createState() =>
      _PassengerRideDetailsScreenState();
}

class _PassengerRideDetailsScreenState
    extends State<PassengerRideDetailsScreen> {
  static const Color kScreenTeal = Color(0xFFE0F9FB);
  static const Color kUniRideTeal2 = Color(0xFF009DAE);
  static const Color kUniRideYellow = Color(0xFFFFC727);

  bool _isRequesting = false;
  GoogleMapController? _mapController;

  void _fitMap(LatLng from, LatLng to) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        (from.latitude <= to.latitude) ? from.latitude : to.latitude,
        (from.longitude <= to.longitude) ? from.longitude : to.longitude,
      ),
      northeast: LatLng(
        (from.latitude >= to.latitude) ? from.latitude : to.latitude,
        (from.longitude >= to.longitude) ? from.longitude : to.longitude,
      ),
    );

    Future.delayed(const Duration(milliseconds: 250), () {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    });
  }

  Future<void> _requestToJoinRide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage("Please log in to request a ride");
      return;
    }

    // prevent driver from requesting own ride
    if (widget.rideData['driverId'] == user.uid) {
      _showMessage("You cannot request your own ride");
      return;
    }

    // prevent requesting if full
    final seatsAvailable = widget.rideData['seatsAvailable'] ?? 0;
    if (seatsAvailable <= 0) {
      _showMessage("This ride is full");
      return;
    }

    // prevent duplicate request
    final existingRequest = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .collection('requests')
        .where('passengerId', isEqualTo: user.uid)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      _showMessage("You have already requested this ride");
      return;
    }

    setState(() => _isRequesting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userProfile = userDoc.data() ?? {};
      final passengerPhone = userProfile['phone'] ?? '';
      final passengerName =
          userProfile['name'] ?? user.displayName ?? 'UniRide User';

      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .collection('requests')
          .add({
        'passengerId': user.uid,
        'passengerName': passengerName,
        'passengerEmail': user.email ?? '',
        'passengerPhone': passengerPhone,
        'driverId': widget.rideData['driverId'],
        'driverName': widget.rideData['driverName'],
        'driverPhone': widget.rideData['driverPhone'] ?? '',
        'from': widget.rideData['from'],
        'to': widget.rideData['to'],
        'date': widget.rideData['date'],
        'time': widget.rideData['time'],
        'price': widget.rideData['price'],
        'seats': 1,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isRequesting = false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PassengerRequestConfirmationScreen(
              driverName: widget.rideData['driverName'],
              from: widget.rideData['from'],
              to: widget.rideData['to'],
              date: widget.rideData['date'],
              time: widget.rideData['time'],
              price: widget.rideData['price']?.toString(),
              seats: "1",
              carMake: widget.rideData['vehicleMake'],
              carModel: widget.rideData['vehicleModel'],
              carColor: widget.rideData['vehicleColor'],
              licensePlate: widget.rideData['vehicleLicensePlate'],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isRequesting = false);
      _showMessage("Error requesting ride: $e");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openChatWithDriver() async {
    final driverId = widget.rideData['driverId'];
    final driverName = widget.rideData['driverName'] ?? 'Driver';

    if (driverId == null) {
      _showMessage('Driver information not available');
      return;
    }

    try {
      final chatRoomId = await ChatService.createOrGetChatRoom(
        otherUserId: driverId,
        otherUserName: driverName,
        rideId: widget.rideId,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatRoomId: chatRoomId,
              otherUserId: driverId,
              otherUserName: driverName,
            ),
          ),
        );
      }
    } catch (e) {
      _showMessage('Error opening chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.rideData;

    final driverName = data['driverName'] ?? 'UniRide User';
    final driverRating = (data['driverRating'] ?? 0).toDouble();

    final carMake = data['vehicleMake'] ?? "Car";
    final carModel = data['vehicleModel'] ?? "";
    final carColor = data['vehicleColor'] ?? "";
    final licensePlate = data['vehicleLicensePlate'] ?? "";

    final from = data['from'] ?? 'Unknown';
    final to = data['to'] ?? 'Unknown';
    final date = data['date'] ?? 'N/A';
    final time = data['time'] ?? 'N/A';
    final price = "${data['price'] ?? 0}";
    final seats = "${data['seatsAvailable'] ?? 0}";

    final fromLat = data['fromLat'];
    final fromLng = data['fromLng'];
    final toLat = data['toLat'];
    final toLng = data['toLng'];

    final dynamic distanceRaw = data['distanceKm'];
    final dynamic durationRaw = data['durationMinutes'];

    final String distanceKm = distanceRaw is num
        ? distanceRaw.toStringAsFixed(1)
        : '?';
    final String durationMin = durationRaw is num
        ? durationRaw.toString()
        : '?';

    LatLng? pickupPoint = (fromLat != null && fromLng != null)
        ? LatLng(fromLat, fromLng)
        : null;
    LatLng? dropoffPoint = (toLat != null && toLng != null)
        ? LatLng(toLat, toLng)
        : null;

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
        centerTitle: true,
        title: const Text(
          "Ride Details",
          style: TextStyle(color: kUniRideTeal2, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DRIVER CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecor(),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: kUniRideTeal2.withOpacity(0.15),
                    child: Text(
                      driverName[0].toUpperCase(),
                      style: const TextStyle(
                        color: kUniRideTeal2,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              driverRating > 0
                                  ? driverRating.toStringAsFixed(1)
                                  : "No rating",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // CAR CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecor(),
              child: Row(
                children: [
                  Icon(Icons.directions_car, size: 30, color: kUniRideTeal2),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$carMake $carModel - $carColor",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "License: $licensePlate",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ROUTE MAP
            if (pickupPoint != null && dropoffPoint != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: _cardDecor(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Route Overview",
                      style: TextStyle(
                        color: kUniRideTeal2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GoogleMap(
                          onMapCreated: (c) {
                            _mapController = c;
                            _fitMap(pickupPoint, dropoffPoint);
                          },
                          initialCameraPosition: CameraPosition(
                            target: pickupPoint,
                            zoom: 12,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId("from"),
                              position: pickupPoint,
                            ),
                            Marker(
                              markerId: const MarkerId("to"),
                              position: dropoffPoint,
                            ),
                          },
                          polylines: {
                            Polyline(
                              polylineId: const PolylineId("route"),
                              points: [pickupPoint, dropoffPoint],
                              color: kUniRideTeal2,
                              width: 4,
                            ),
                          },
                          zoomControlsEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$distanceKm km  •  ~$durationMin mins",
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            const Text(
              "Ride Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _info("Pickup", from),
            _info("Destination", to),
            _info("Date", date),
            _info("Time", time),
            _info(
              "Seats Available",
              int.tryParse(seats) == 0
                  ? "Full"
                  : "$seats seat${(int.tryParse(seats) ?? 0) > 1 ? "s" : ""}",
            ),
            _info("Price", "BD $price"),

            const SizedBox(height: 30),

            _actionBtn(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecor() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ],
  );

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 15),
            ),
          ),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn() {
    final user = FirebaseAuth.instance.currentUser;

    // driver shouldn't see a button on own ride
    if (widget.rideData['driverId'] == user?.uid) {
      return const SizedBox.shrink();
    }

    final seatsAvailable = widget.rideData['seatsAvailable'] ?? 0;
    if (seatsAvailable <= 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade400,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text("Ride Full", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .collection('requests')
          .where('passengerId', isEqualTo: user?.uid ?? '')
          .get(),
      builder: (context, snapshot) {
        final hasRequest = snapshot.data?.docs.isNotEmpty ?? false;
        final status = hasRequest
            ? snapshot.data!.docs.first['status'] as String?
            : null;
        final accepted = status == "accepted";
        final requestId = hasRequest ? snapshot.data!.docs.first.id : null;

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openChatWithDriver(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text("Chat with Driver"),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: accepted
                    ? null
                    : (_isRequesting ? null : _requestToJoinRide),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accepted
                      ? Colors.grey.shade400
                      : kUniRideYellow,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isRequesting
                    ? const CircularProgressIndicator(
                        color: Colors.black87,
                        strokeWidth: 2,
                      )
                    : Text(
                        accepted ? "Request Accepted" : "Request to Join Ride",
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (hasRequest && requestId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelRequestWithReason(requestId),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Cancel Request"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _cancelRequestWithReason(String requestId) async {
    showDialog(
      context: context,
      builder: (_) => _CancellationReasonDialog(
        onCancel: (reason) async {
          Navigator.pop(context);

          try {
            final requestDoc = await FirebaseFirestore.instance
                .collection('ride_requests')
                .doc(requestId)
                .get();

            final requestData = requestDoc.data() ?? {};
            final seatsBooked = requestData['seats'] ?? 1;
            final rideId = widget.rideId;

            // Update ride request status
            await FirebaseFirestore.instance
                .collection('ride_requests')
                .doc(requestId)
                .update({
                  'status': 'cancelled',
                  'cancellationReason': reason,
                  'cancelledAt': FieldValue.serverTimestamp(),
                });

            // Increase available seats on the ride
            await FirebaseFirestore.instance
                .collection('rides')
                .doc(rideId)
                .update({'seatsAvailable': FieldValue.increment(seatsBooked)});

            _showMessage("Request cancelled");
            if (mounted) {
              Navigator.pop(context);
            }
          } catch (e) {
            _showMessage("Error cancelling request: $e");
          }
        },
      ),
    );
  }
}

class _CancellationReasonDialog extends StatefulWidget {
  final Function(String reason) onCancel;

  const _CancellationReasonDialog({required this.onCancel});

  @override
  State<_CancellationReasonDialog> createState() =>
      _CancellationReasonDialogState();
}

class _CancellationReasonDialogState extends State<_CancellationReasonDialog> {
  final TextEditingController _reasonController = TextEditingController();
  final List<String> _presetReasons = [
    "Plans changed",
    "Found another ride",
    "No longer needed",
    "Other reason",
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Cancel Request?"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please let the driver know why you're cancelling:",
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ...List.generate(_presetReasons.length, (index) {
              final reason = _presetReasons[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => widget.onCancel(reason),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF009DAE),
                      side: const BorderSide(color: Color(0xFF009DAE)),
                    ),
                    child: Text(reason),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Or type your own reason...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Keep Request"),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _reasonController.text.trim().isEmpty
                ? "No reason provided"
                : _reasonController.text.trim();
            widget.onCancel(reason);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text("Cancel"),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
