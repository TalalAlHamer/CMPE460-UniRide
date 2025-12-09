import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color kScreenTeal = Color(0xFFE0F9FB);
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
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rides")
          .doc(widget.rideId)
          .snapshots(),
      builder: (context, rideSnap) {
        if (!rideSnap.hasData) {
          return Scaffold(
            backgroundColor: kScreenTeal,
            body: const Center(
              child: CircularProgressIndicator(color: kUniRideTeal2),
            ),
          );
        }

        final ride =
            rideSnap.data!.data() as Map<String, dynamic>? ?? widget.rideData;

        final from = ride["from"] ?? "Unknown";
        final to = ride["to"] ?? "Unknown";
        final date = ride["date"] ?? "N/A";
        final time = ride["time"] ?? "N/A";
        final price = (ride["price"] ?? 0).toString();
        final totalSeats = ride["seats"] ?? 0;
        final seatsAvailable = ride["seatsAvailable"] ?? 0;
        final bookedSeats = totalSeats - seatsAvailable;

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

          // =============================== BODY ===============================
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --------------------------------------------------
                // ROUTE CARD
                // --------------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: _box(),
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
                      _row("From", from),
                      const SizedBox(height: 8),
                      _row("To", to),
                      const Divider(height: 20),
                      _row("Date", date),
                      _row("Time", time),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --------------------------------------------------
                // RIDE DETAILS CARD
                // --------------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: _box(),
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
                      _row("Total Seats", totalSeats.toString()),
                      _row("Booked Seats", bookedSeats.toString()),
                      _row("Available Seats", seatsAvailable.toString()),
                      const Divider(height: 20),
                      _row("Price (per seat)", "BD $price"),
                      _row(
                        "Total Earnings",
                        "BD ${(bookedSeats * double.parse(price)).toStringAsFixed(2)}",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --------------------------------------------------
                // RECENT UPDATES — PASSENGER CANCELLATIONS
                // --------------------------------------------------
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("ride_requests")
                      .where("rideId", isEqualTo: widget.rideId)
                      .where("status", isEqualTo: "cancelled_by_passenger")
                      .snapshots(),
                  builder: (context, cancelSnap) {
                    if (!cancelSnap.hasData || cancelSnap.data!.docs.isEmpty) {
                      return const SizedBox();
                    }

                    final docs = cancelSnap.data!.docs;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Recent Updates",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kUniRideTeal2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...docs.map(
                          (d) => _cancelCard(d.data() as Map<String, dynamic>),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),

                // --------------------------------------------------
                // BOOKED PASSENGERS
                // --------------------------------------------------
                const Text(
                  "Booked Passengers",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kUniRideTeal2,
                  ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("ride_requests")
                      .where("rideId", isEqualTo: widget.rideId)
                      .where("status", isEqualTo: "accepted")
                      .snapshots(),
                  builder: (context, passSnap) {
                    if (!passSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: kUniRideTeal2),
                      );
                    }

                    final passengers = passSnap.data!.docs;

                    if (passengers.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: _box(),
                        child: const Center(
                          child: Text(
                            "No passengers booked yet",
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: passengers.map((p) {
                        final data = p.data() as Map<String, dynamic>;
                        return _passengerCard(data);
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // --------------------------------------------------
                // BUTTON
                // --------------------------------------------------
                ElevatedButton(
                  onPressed: bookedSeats == 0 ? null : _endRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kUniRideYellow,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "End Ride",
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================================
  // UI HELPERS
  // =====================================================================

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelCard(Map<String, dynamic> data) {
    final name = data["passengerName"] ?? "Passenger";
    final reason = data["cancelReason"] ?? "No reason given";
    final ts = data["cancelledAt"] as Timestamp?;
    final t = ts != null ? ts.toDate() : null;
    final time = t == null
        ? "--:--"
        : "${t.hour}:${t.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$name cancelled their booking",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Reason: $reason",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            "Time: $time",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _passengerCard(Map<String, dynamic> data) {
    final name = data["passengerName"] ?? "Passenger";
    final email = data["passengerEmail"] ?? "—";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: kUniRideTeal2,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                email,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Future<void> _endRide() async {
    await FirebaseFirestore.instance
        .collection("rides")
        .doc(widget.rideId)
        .update({"status": "completed"});

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ride ended successfully.")));
      Navigator.pop(context);
    }
  }
}
