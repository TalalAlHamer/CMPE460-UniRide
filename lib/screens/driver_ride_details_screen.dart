// 🔵 PAGE: lib/screens/driver_ride_details_screen.dart
// ✔ Exact same UI you designed
// ✔ Added "Recent Updates" section for cancellations
// ✔ Live streams for seats + passengers
// ✔ Fully stable

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rating_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import '../services/chat_service.dart';

const Color kScreenTeal = Color(0xFFE0F9FB);
const Color kUniRideTeal1 = Color(0xFF00BCC9);
const Color kUniRideTeal2 = Color(0xFF009DAE);
const Color kUniRideYellow = Color(0xFFFFC727);

class DriverRideDetailsScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const DriverRideDetailsScreen({
    super.key,
    required this.rideId,
    required this.rideData,
  });

  @override
  State<DriverRideDetailsScreen> createState() =>
      _DriverRideDetailsScreenState();
}

class _DriverRideDetailsScreenState extends State<DriverRideDetailsScreen> {
  List<Map<String, dynamic>> acceptedPassengers = [];

  Future<void> _openChatWithPassenger(Map<String, dynamic> passenger) async {
    final passengerId = passenger['passengerId'];
    final passengerName = passenger['passengerName'] ?? 'Passenger';

    if (passengerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passenger information not available')),
      );
      return;
    }

    try {
      final chatRoomId = await ChatService.createOrGetChatRoom(
        otherUserId: passengerId,
        otherUserName: passengerName,
        rideId: widget.rideId,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatRoomId: chatRoomId,
              otherUserId: passengerId,
              otherUserName: passengerName,
            ),
          ),
        );
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
      }
    }
  }

  // 🚗 End Ride → Go to Rating Screen
  Future<void> _endRide() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Check if ride is already completed to prevent duplicate increments
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();

      if (rideDoc.data()?['status'] == 'completed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This ride has already been completed'),
            ),
          );
        }
        return;
      }

      // Fetch accepted passengers from Firestore FIRST
      final acceptedRequestsSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .collection('requests')
          .where('status', isEqualTo: 'accepted')
          .get();

      final acceptedPassengersList = acceptedRequestsSnapshot.docs
          .map(
            (doc) => {
              'passengerId': doc['passengerId'],
              'passengerName': doc['passengerName'] ?? 'Passenger',
              ...doc.data(),
            },
          )
          .toList();

      // Use batch to ensure all updates happen atomically
      final batch = FirebaseFirestore.instance.batch();

      // Mark ride as completed
      final rideRef = FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId);
      batch.update(rideRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Increment ride count for driver
      final driverRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      batch.update(driverRef, {'totalRides': FieldValue.increment(1)});

      // Get all ride requests for this ride to update their status
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .collection('requests')
          .get();

      // Update all ride requests to completed status
      for (final requestDoc in requestsSnapshot.docs) {
        batch.update(requestDoc.reference, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      // Increment ride count for all accepted passengers and create pending ratings
      for (final passenger in acceptedPassengersList) {
        final passengerId = passenger['passengerId'];

        // Increment passenger ride count
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(passengerId);
        batch.update(userRef, {'totalRides': FieldValue.increment(1)});

        // Create pending rating for passenger to rate driver
        final pendingRatingRef = FirebaseFirestore.instance
            .collection('pending_ratings')
            .doc();
        batch.set(pendingRatingRef, {
          'passengerId': passengerId,
          'driverId': currentUser.uid,
          'driverName': widget.rideData['driverName'] ?? 'Driver',
          'rideId': widget.rideId,
          'from': widget.rideData['from'],
          'to': widget.rideData['to'],
          'date': widget.rideData['date'],
          'time': widget.rideData['time'],
          'createdAt': FieldValue.serverTimestamp(),
          'completed': false,
        });
      }

      await batch.commit();

      // Navigate to rating screen for driver to rate passengers
      final usersToRate = acceptedPassengersList
          .map(
            (p) => {
              'userId': p['passengerId'],
              'name': p['passengerName'] ?? 'Passenger',
            },
          )
          .toList();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RatingScreen(
              rideId: widget.rideId,
              isDriver: true,
              usersToRate: usersToRate,
            ),
          ),
        );
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error ending ride: $e')));
      }
    }
  }

  // ❌ Driver Cancels Entire Ride
  Future<void> _cancelRide(String currentStatus) async {
    // Prevent canceling if already cancelled
    if (currentStatus == "cancelled") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This ride is already cancelled"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Ride?"),
        content: const Text(
          "This will cancel the ride and remove it from search results.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Keep Ride"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await FirebaseFirestore.instance
                  .collection("rides")
                  .doc(widget.rideId)
                  .update({
                    "status": "cancelled",
                    "cancelledAt": FieldValue.serverTimestamp(),
                  });

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Ride cancelled"),
                  backgroundColor: Colors.red,
                ),
              );

              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text(
              "Cancel Ride",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ Live Ride Updates
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rides")
          .doc(widget.rideId)
          .snapshots(),
      builder: (context, rideSnapshot) {
        if (!rideSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kScreenTeal,
            body: const Center(
              child: CircularProgressIndicator(color: kUniRideTeal2),
            ),
          );
        }

        final rideData =
            rideSnapshot.data!.data() as Map<String, dynamic>? ??
            widget.rideData;

        final totalSeats = rideData['seats'] ?? 0;
        final seatsAvailable = rideData['seatsAvailable'] ?? 0;
        final bookedSeats = totalSeats - seatsAvailable;

        final from = rideData['from'] ?? "—";
        final to = rideData['to'] ?? "—";
        final date = rideData['date'] ?? "—";
        final time = rideData['time'] ?? "—";
        final price = rideData['price'].toString();

        final distance = rideData['distanceKm']?.toStringAsFixed(1) ?? "—";
        final duration = rideData['durationMinutes']?.toString() ?? "—";

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
              style: TextStyle(
                color: kUniRideTeal2,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ROUTE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Route",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _rideInfoRow("From", from),
                      const SizedBox(height: 8),
                      _rideInfoRow("To", to),
                      const Divider(height: 20),
                      _rideInfoRow("Date", date),
                      _rideInfoRow("Time", time),
                      _rideInfoRow("Distance", "$distance km"),
                      _rideInfoRow("Duration", "$duration min"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // DETAILS CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Ride Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _rideInfoRow("Total Seats", totalSeats.toString()),
                      _rideInfoRow("Booked Seats", bookedSeats.toString()),
                      _rideInfoRow(
                        "Available Seats",
                        seatsAvailable.toString(),
                      ),
                      const Divider(height: 20),
                      _rideInfoRow("Price per Seat", "BD $price"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Booked Passengers",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                // ⭐ LIVE ACCEPTED PASSENGERS STREAM BUILDER
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rides')
                      .doc(widget.rideId)
                      .collection('requests')
                      .where('status', isEqualTo: 'accepted')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: kUniRideTeal2),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    // Update acceptedPassengers list for rating screen
                    acceptedPassengers = docs
                        .map(
                          (doc) => {
                            'requestId': doc.id,
                            ...doc.data() as Map<String, dynamic>,
                          },
                        )
                        .toList();

                    if (docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "No passengers booked yet",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }

                    final passengerCards = docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _passengerCard({'requestId': doc.id, ...data});
                    }).toList();

                    // Add End Ride button after passengers if user is driver
                    final user = FirebaseAuth.instance.currentUser;
                    final isDriver = user?.uid == rideData['driverId'];

                    return Column(
                      children: [
                        ...passengerCards,
                        if (isDriver) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _endRide,
                                  icon: const Icon(Icons.flag, size: 20),
                                  label: const Text("End Ride"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kUniRideYellow,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelRide(
                                    rideData['status'] ?? 'active',
                                  ),
                                  icon: const Icon(Icons.close, size: 20),
                                  label: const Text("Cancel Ride"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  "Cancellations",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                // ⭐ CANCELLED REQUESTS STREAM BUILDER
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rides')
                      .doc(widget.rideId)
                      .collection('requests')
                      .where('status', isEqualTo: 'cancelled')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "No cancellations yet",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final reason =
                            data['cancellationReason'] ?? "No reason provided";
                        return _cancellationReasonCard(reason);
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🔥 FIXED HERE — NOW TEXT WRAPS AND NEVER OVERFLOWS
  Widget _rideInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ),

          /// 🔥 This Expanded makes the text wrap safely
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passengerCard(Map<String, dynamic> passenger) {
    final name = passenger["passengerName"] ?? "Passenger";
    final email = passenger["passengerEmail"] ?? "";
    final seats = passenger["seats"] ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: kUniRideTeal1,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kUniRideTeal2.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kUniRideTeal2),
            ),
            child: Text(
              "$seats seat${seats > 1 ? "s" : ""}",
              style: const TextStyle(
                color: kUniRideTeal2,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: kUniRideTeal2),
            onPressed: () => _openChatWithPassenger(passenger),
            tooltip: 'Chat',
          ),
        ],
      ),
    );
  }

  Widget _cancellationReasonCard(String reason) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Cancellation Reason",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
