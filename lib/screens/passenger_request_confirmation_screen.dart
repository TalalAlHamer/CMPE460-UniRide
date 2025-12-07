import 'package:flutter/material.dart';
import 'my_rides_screen.dart';

class PassengerRequestConfirmationScreen extends StatelessWidget {
  final String? driverName;
  final String? from;
  final String? to;
  final String? date;
  final String? time;
  final String? price;
  final String? seats;
  final String? carMake;
  final String? carModel;
  final String? carColor;
  final String? licensePlate;

  const PassengerRequestConfirmationScreen({
    super.key,
    this.driverName,
    this.from,
    this.to,
    this.date,
    this.time,
    this.price,
    this.seats,
    this.carMake,
    this.carModel,
    this.carColor,
    this.licensePlate,
  });

  static const Color kScreenTeal = Color(0xFFE0F9FB);
  static const Color kUniRideTeal1 = Color(0xFF00BCC9);
  static const Color kUniRideTeal2 = Color(0xFF009DAE);
  static const Color kUniRideYellow = Color(0xFFFFC727);

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
        centerTitle: true,
        title: const Text(
          "Request Sent",
          style: TextStyle(
            color: kUniRideTeal2,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 10),

            // SUCCESS ICON
            CircleAvatar(
              radius: 45,
              backgroundColor: kUniRideTeal2.withOpacity(0.15),
              child: const Icon(
                Icons.check_circle,
                color: kUniRideTeal2,
                size: 60,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Request Sent!",
              style: TextStyle(
                color: kUniRideTeal2,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Your request has been sent to the driver.\nYou'll be notified once they accept it.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),

            const SizedBox(height: 30),

            // RIDE SUMMARY CARD
            Container(
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
                  // Driver info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: kUniRideTeal2,
                        child: Text(
                          (driverName ?? "D").substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          driverName ?? "Driver Name",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
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
                          from ?? "N/A",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
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
                          to ?? "N/A",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Date with icon
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          date ?? "N/A",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Time with icon
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          time ?? "N/A",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (carMake != null ||
                      carModel != null ||
                      carColor != null ||
                      licensePlate != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],

                  // Vehicle info
                  if (carMake != null || carModel != null) ...[
                    _infoRow(
                      "Vehicle",
                      "${carMake ?? ''} ${carModel ?? ''}".trim(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (carColor != null) ...[
                    _infoRow("Color", carColor!),
                    const SizedBox(height: 8),
                  ],
                  if (licensePlate != null) _infoRow("License", licensePlate!),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Price & Seats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Seats",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            seats ?? "1",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "Price",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "BD ${price ?? '0.00'}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kUniRideTeal2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // STATUS BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: kUniRideTeal2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Pending Approval",
                style: TextStyle(
                  color: kUniRideTeal2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // BACK TO HOME
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kUniRideYellow,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Back to Home",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // TRACK REQUEST STATUS
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyRidesScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kUniRideTeal2, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Track Request Status",
                  style: TextStyle(
                    color: kUniRideTeal2,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
