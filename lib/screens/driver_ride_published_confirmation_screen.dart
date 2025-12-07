import 'package:flutter/material.dart';
import 'my_rides_screen.dart';

class DriverRidePublishedConfirmationScreen extends StatelessWidget {
  final String from;
  final String to;
  final String date;
  final String time;
  final String price;

  const DriverRidePublishedConfirmationScreen({
    super.key,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.price,
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kUniRideTeal2,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Ride Published",
          style: TextStyle(
            color: kUniRideTeal2,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 10),

            /// SUCCESS ICON
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
              "Ride Successfully Published!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kUniRideTeal2,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Other students can now see and request\n to join your ride.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),

            const SizedBox(height: 30),

            /// RIDE DETAILS CARD - Updated design matching My Rides
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
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Active",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // From location with icon
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          from,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // To location with icon
                  Row(
                    children: [
                      const Icon(Icons.flag, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          to,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date, Time, Price row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            time,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                      Text(
                        "BD $price",
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

            const Spacer(),

            /// BACK TO HOME
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

            const SizedBox(height: 14),

            /// VIEW MY OFFERED RIDES
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyRidesScreen(initialTabIndex: 1),
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
                  "View My Offered Rides",
                  style: TextStyle(
                    color: kUniRideTeal2,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
