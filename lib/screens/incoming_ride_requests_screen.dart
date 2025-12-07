import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rating_screen.dart';
import 'package:uniride_app/services/rating_service.dart';

class IncomingRideRequestsScreen extends StatefulWidget {
  const IncomingRideRequestsScreen({super.key});

  @override
  State<IncomingRideRequestsScreen> createState() => _IncomingRideRequestsScreenState();
}

class _IncomingRideRequestsScreenState extends State<IncomingRideRequestsScreen> {
  static const Color kScreenTeal = Color(0xFFE0F9FB);
  static const Color kUniRideTeal1 = Color(0xFF00BCC9);
  static const Color kUniRideTeal2 = Color(0xFF009DAE);

  // final RideService _rideService =
  //     RideService(); // used in decline (future use)

  /// ✅ ACCEPT REQUEST:
  /// - Mark request as 'accepted'
  /// - Decrease seatsAvailable on the ride
  Future<void> _acceptRequest(String requestId, String rideId) async {
    try {
      final db = FirebaseFirestore.instance;

      // 🔹 First, mark the request as accepted
      final requestRef = db.collection('rides').doc(rideId).collection('requests').doc(requestId);
      await requestRef.update({'status': 'accepted'});

      // 🔹 Then, safely decrement seatsAvailable on the ride
      final rideRef = db.collection('rides').doc(rideId);

      await db.runTransaction((txn) async {
        final snap = await txn.get(rideRef);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        final current = data['seatsAvailable'];

        int seatsAvailable;
        if (current is int) {
          seatsAvailable = current;
        } else {
          seatsAvailable = int.tryParse(current.toString()) ?? 0;
        }

        if (seatsAvailable > 0) {
          txn.update(rideRef, {'seatsAvailable': seatsAvailable - 1});
        }
      });

      _showMessage("Request accepted!");
    } catch (e) {
      _showMessage("Error accepting request: $e");
    }
  }

  /// DECLINE REQUEST:
  /// - Only changes status to 'declined'
  /// - We do NOT touch seats here because they are only reduced on accept
  Future<void> _declineRequest(String requestId, String rideId) async {
    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .collection('requests')
          .doc(requestId)
          .update({'status': 'declined'});

      // Note: _rideService.cancelSeat(rideId) is NOT called here
      // because seatsAvailable is only reduced when accepting a request.
      // If you later add "un-accept" logic, you can use cancelSeat there.

      _showMessage("Request declined");
    } catch (e) {
      _showMessage("Error declining request: $e");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          "Incoming Ride Requests",
          style: TextStyle(
            color: kUniRideTeal2,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text(
                "Please log in to view ride requests",
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('requests')
                  .where('driverId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kUniRideTeal2),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Error loading requests",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 80,
                            color: Colors.black26,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No ride requests yet",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Requests from passengers will appear here",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black38,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final requests = snapshot.data!.docs;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = requests[index];
                      final data = doc.data() as Map<String, dynamic>;
                      // Get rideId from the parent document reference (since it's in a subcollection)
                      final rideId = doc.reference.parent.parent?.id ?? '';

                      return _requestCard(
                        requestId: doc.id,
                        rideId: rideId,
                        passengerId: data['passengerId'] ?? '',
                        passengerName: data['passengerName'] ?? 'UniRide User',
                        pickup: data['from'] ?? 'Unknown',
                        destination: data['to'] ?? 'Unknown',
                        time: data['time'] ?? 'N/A',
                        date: data['date'] ?? 'N/A',
                        price: data['price']?.toString() ?? '0.0',
                        status: data['status'] ?? 'pending',
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _requestCard({
    required String requestId,
    required String rideId,
    required String passengerId,
    required String passengerName,
    required String pickup,
    required String destination,
    required String time,
    required String date,
    required String price,
    required String status,
  }) {
    final Color statusColor;
    switch (status) {
      case "accepted":
        statusColor = Colors.green;
        break;
      case "declined":
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = kUniRideTeal2;
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: kUniRideTeal1,
                child: Text(
                  passengerName.isNotEmpty
                      ? passengerName[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<double>(
                      future: RatingService.getAverageRating(passengerId),
                      builder: (context, snapshot) {
                        final rating = snapshot.data ?? 0.0;
                        return Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: rating > 0 ? Colors.amber : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating > 0
                                  ? rating.toStringAsFixed(1)
                                  : "No rating",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  status == 'accepted'
                      ? 'Accepted'
                      : status == 'declined'
                      ? 'Declined'
                      : 'Pending',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: kUniRideTeal2),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pickup,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.arrow_downward, size: 16, color: Colors.black38),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destination,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(width: 16),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                "BD $price",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kUniRideTeal2,
                ),
              ),
            ],
          ),

          if (status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _declineRequest(requestId, rideId),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red[700],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red[200]!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptRequest(requestId, rideId),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[50],
                      foregroundColor: Colors.green[700],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.green[200]!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'accepted') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RatingScreen(
                        rideId: rideId,
                        isDriver: true,
                        usersToRate: [
                          {'userId': passengerId, 'name': passengerName},
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.flag, size: 18),
                label: const Text('Finish Ride'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFC727),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
