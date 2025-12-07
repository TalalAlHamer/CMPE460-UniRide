import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'driver_ride_details_screen.dart';
import 'passenger_ride_details_screen.dart';
import 'widgets/bottom_nav.dart';

const Color kScreenTeal = Color(0xFFE0F9FB);
const Color kUniRideTeal1 = Color(0xFF00BCC9);
const Color kUniRideTeal2 = Color(0xFF009DAE);
const Color kUniRideYellow = Color(0xFFFFC727);

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kScreenTeal,
      appBar: AppBar(
        backgroundColor: kScreenTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: kUniRideTeal2),
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "My Rides",
          style: TextStyle(
            color: kUniRideTeal2,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kUniRideTeal2,
          unselectedLabelColor: Colors.black54,
          indicatorColor: kUniRideTeal2,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Requested Rides"),
            Tab(text: "Offered Rides"),
          ],
        ),
      ),
      body: user == null
          ? const Center(child: Text("Please log in to view your rides"))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestedRidesTab(user.uid),
                _buildOfferedRidesTab(user.uid),
              ],
            ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }

  Widget _buildOfferedRidesTab(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rides")
          .where("driverId", isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kUniRideTeal2),
          );
        }

        if (snapshot.hasError) {
          print('Error loading rides: ${snapshot.error}');
          return Center(
            child: Text(
              "Error loading rides: ${snapshot.error}",
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          );
        }

        print('User ID: $userId');
        print('Rides found: ${snapshot.data?.docs.length ?? 0}');
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "You haven't offered any rides yet.",
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "User ID: $userId",
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final rides = snapshot.data!.docs;
        final now = DateTime.now();
        
        // Separate into upcoming and past rides
        final upcomingRides = <QueryDocumentSnapshot>[];
        final pastRides = <QueryDocumentSnapshot>[];
        
        for (final ride in rides) {
          final data = ride.data() as Map<String, dynamic>;
          final rideDateTime = _parseDateTime(data['date'], data['time']);
          
          if (rideDateTime.isAfter(now)) {
            upcomingRides.add(ride);
          } else {
            pastRides.add(ride);
          }
        }
        
        // Sort both lists by time (nearest first for upcoming, most recent first for past)
        upcomingRides.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDateTime = _parseDateTime(aData['date'], aData['time']);
          final bDateTime = _parseDateTime(bData['date'], bData['time']);
          return aDateTime.compareTo(bDateTime);
        });
        
        pastRides.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDateTime = _parseDateTime(aData['date'], aData['time']);
          final bDateTime = _parseDateTime(bData['date'], bData['time']);
          return bDateTime.compareTo(aDateTime); // Reverse for most recent first
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: upcomingRides.length + pastRides.length + 
                    (upcomingRides.isNotEmpty && pastRides.isNotEmpty ? 2 : 0),
          itemBuilder: (context, index) {
            // Upcoming rides section
            if (upcomingRides.isNotEmpty && index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  "Upcoming Rides",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kUniRideTeal2,
                  ),
                ),
              );
            }
            
            if (index > 0 && index <= upcomingRides.length) {
              final doc = upcomingRides[index - 1];
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _rideCard(doc.id, data),
              );
            }
            
            // Past rides section header
            if (pastRides.isNotEmpty && index == upcomingRides.length + (upcomingRides.isNotEmpty ? 1 : 0)) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: 12,
                  top: upcomingRides.isNotEmpty ? 12 : 4,
                ),
                child: const Text(
                  "Past Rides",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              );
            }
            
            // Past rides
            final pastIndex = index - upcomingRides.length - (upcomingRides.isNotEmpty ? 1 : 0) - 1;
            final doc = pastRides[pastIndex];
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _rideCard(doc.id, data),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestedRidesTab(String userId) {
    print('========== BUILDING REQUESTED RIDES TAB ==========');
    print('User ID for query: $userId');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('passengerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        print('StreamBuilder callback - connectionState: ${snapshot.connectionState}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Waiting for data...');
          return const Center(
            child: CircularProgressIndicator(color: kUniRideTeal2),
          );
        }

        print('Has data: ${snapshot.hasData}');
        print('Has error: ${snapshot.hasError}');
        if (snapshot.hasError) {
          print('Error: ${snapshot.error}');
        }
        print('Docs count: ${snapshot.data?.docs.length ?? 0}');
        
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          print('Found ${snapshot.data!.docs.length} ride requests:');
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            print('  - Request ${doc.id}: status=${data['status']}, from=${data['from']}, to=${data['to']}');
          }
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('No ride requests found for user $userId');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "You haven't requested any rides yet.",
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "User ID: $userId",
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  "Collection: ride_requests",
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // Separate into upcoming and past requests
        final requests = snapshot.data!.docs;
        final now = DateTime.now();
        print('Current time: $now');
        
        final upcomingRequests = <QueryDocumentSnapshot>[];
        final pastRequests = <QueryDocumentSnapshot>[];
        
        for (final request in requests) {
          final data = request.data() as Map<String, dynamic>;
          final requestDateTime = _parseDateTime(data['date'], data['time']);
          print('Request: ${data['from']} -> ${data['to']}');
          print('  Date string: ${data['date']}, Time string: ${data['time']}');
          print('  Parsed DateTime: $requestDateTime');
          print('  Is after now? ${requestDateTime.isAfter(now)}');
          
          if (requestDateTime.isAfter(now)) {
            print('  -> Adding to UPCOMING');
            upcomingRequests.add(request);
          } else {
            print('  -> Adding to PAST');
            pastRequests.add(request);
          }
        }
        
        print('Total upcoming: ${upcomingRequests.length}');
        print('Total past: ${pastRequests.length}');
        
        // Sort both lists by time (nearest first for upcoming, most recent first for past)
        upcomingRequests.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDateTime = _parseDateTime(aData['date'], aData['time']);
          final bDateTime = _parseDateTime(bData['date'], bData['time']);
          return aDateTime.compareTo(bDateTime);
        });
        
        pastRequests.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDateTime = _parseDateTime(aData['date'], aData['time']);
          final bDateTime = _parseDateTime(bData['date'], bData['time']);
          return bDateTime.compareTo(aDateTime); // Reverse for most recent first
        });

        // Calculate item count: items + headers
        final upcomingHeaderCount = upcomingRequests.isNotEmpty ? 1 : 0;
        final pastHeaderCount = pastRequests.isNotEmpty ? 1 : 0;
        final totalItemCount = upcomingRequests.length + pastRequests.length + upcomingHeaderCount + pastHeaderCount;
        
        print('Item count: $totalItemCount (${upcomingRequests.length} upcoming + ${pastRequests.length} past + $upcomingHeaderCount upcoming header + $pastHeaderCount past header)');
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: totalItemCount,
          itemBuilder: (context, index) {
            print('Building item at index $index');
            // Upcoming requests section
            if (upcomingRequests.isNotEmpty && index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  "Upcoming Requests",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kUniRideTeal2,
                  ),
                ),
              );
            }
            
            if (index > 0 && index <= upcomingRequests.length) {
              final doc = upcomingRequests[index - 1];
              final data = doc.data() as Map<String, dynamic>;
              final rideId = data['rideId'] ?? '';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _passengerRequestCard(
                  requestId: doc.id,
                  rideId: rideId,
                  driverName: data['driverName'] ?? 'Unknown',
                  status: data['status'] ?? 'pending',
                  from: data['from'] ?? 'Unknown',
                  to: data['to'] ?? 'Unknown',
                  date: data['date'] ?? 'N/A',
                  time: data['time'] ?? 'N/A',
                  price: data['price']?.toString() ?? '0.0',
                ),
              );
            }
            
            // Past requests section header
            if (pastRequests.isNotEmpty && index == upcomingRequests.length + (upcomingRequests.isNotEmpty ? 1 : 0)) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: 12,
                  top: upcomingRequests.isNotEmpty ? 12 : 4,
                ),
                child: const Text(
                  "Past Requests",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              );
            }
            
            // Past requests
            final pastIndex = index - upcomingRequests.length - (upcomingRequests.isNotEmpty ? 1 : 0) - 1;
            final doc = pastRequests[pastIndex];
            final data = doc.data() as Map<String, dynamic>;
            final rideId = data['rideId'] ?? '';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _passengerRequestCard(
                requestId: doc.id,
                rideId: rideId,
                driverName: data['driverName'] ?? 'Unknown',
                status: data['status'] ?? 'pending',
                from: data['from'] ?? 'Unknown',
                to: data['to'] ?? 'Unknown',
                date: data['date'] ?? 'N/A',
                time: data['time'] ?? 'N/A',
                price: data['price']?.toString() ?? '0.0',
              ),
            );
          },
        );
      },
    );
  }

  DateTime _parseDateTime(String? date, String? time) {
    if (date == null || time == null) return DateTime.now();
    try {
      // Date format: "DD/MM/YYYY", Time format: "HH:mm AM/PM"
      final dateParts = date.split('/');
      if (dateParts.length != 3) return DateTime.now();
      
      // Parse time with AM/PM
      final timeUpper = time.toUpperCase();
      final isPM = timeUpper.contains('PM');
      final timeOnly = timeUpper.replaceAll('AM', '').replaceAll('PM', '').trim();
      final timeParts = timeOnly.split(':');
      
      if (timeParts.length >= 2) {
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        // Convert to 24-hour format
        if (isPM && hour != 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }
        
        return DateTime(
          int.parse(dateParts[2]), // year
          int.parse(dateParts[1]), // month
          int.parse(dateParts[0]), // day
          hour,
          minute,
        );
      }
    } catch (e) {
      print('Error parsing date/time: $e');
    }
    return DateTime.now();
  }

  Widget _rideCard(String rideId, Map<String, dynamic> data) {
    final from = data["from"] ?? "Unknown";
    final to = data["to"] ?? "Unknown";
    final date = data["date"] ?? "—";
    final time = data["time"] ?? "—";
    final price = data["price"]?.toString() ?? "0.0";
    final seatsAvailable = data["seatsAvailable"] ?? 0;
    final status = data["status"] ?? "active";
    
    // Check if ride time has passed
    final rideDateTime = _parseDateTime(date, time);
    final isExpired = rideDateTime.isBefore(DateTime.now());
    final displayStatus = isExpired ? "expired" : status;
    
    final Color statusColor;
    final String statusText;
    switch (displayStatus) {
      case "active":
        statusColor = Colors.green;
        statusText = "Active";
        break;
      case "cancelled":
        statusColor = Colors.grey;
        statusText = "Cancelled";
        break;
      case "expired":
        statusColor = Colors.orange;
        statusText = "Expired";
        break;
      default:
        statusColor = Colors.grey;
        statusText = "Inactive";
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DriverRideDetailsScreen(rideId: rideId, rideData: data),
          ),
        );
      },
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
            // Status badge + seats info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: seatsAvailable <= 0
                        ? Colors.red.withOpacity(0.15)
                        : kUniRideTeal2.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    seatsAvailable <= 0
                        ? "Full"
                        : "$seatsAvailable seat${seatsAvailable > 1 ? "s" : ""} left",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: seatsAvailable <= 0 ? Colors.red : kUniRideTeal2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // From -> To with icons
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

            // Date, Time, Price
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
            const SizedBox(height: 12),

            // View Details button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DriverRideDetailsScreen(
                        rideId: rideId,
                        rideData: data,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kUniRideTeal2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            // Cancel button (only for active rides)
            if (displayStatus == "active") ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelRide(rideId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text("Cancel Ride"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _passengerRequestCard({
    required String requestId,
    required String rideId,
    required String driverName,
    required String status,
    required String from,
    required String to,
    required String date,
    required String time,
    required String price,
  }) {
    // Check if request time has passed
    final requestDateTime = _parseDateTime(date, time);
    final isExpired = requestDateTime.isBefore(DateTime.now());
    final displayStatus = isExpired && status != "cancelled" ? "expired" : status;
    
    final Color statusColor;
    final String statusText;
    switch (displayStatus) {
      case "accepted":
        statusColor = Colors.green;
        statusText = "Accepted";
        break;
      case "declined":
        statusColor = Colors.redAccent;
        statusText = "Declined";
        break;
      case "cancelled":
        statusColor = Colors.grey;
        statusText = "Cancelled";
        break;
      case "expired":
        statusColor = Colors.orange;
        statusText = "Expired";
        break;
      default:
        statusColor = Colors.orange;
        statusText = "Pending";
    }

    return GestureDetector(
      onTap: () async {
        // Fetch the full ride data and navigate to PassengerRideDetailsScreen
        final rideDoc = await FirebaseFirestore.instance
            .collection('rides')
            .doc(rideId)
            .get();
        
        if (rideDoc.exists && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PassengerRideDetailsScreen(
                rideId: rideId,
                rideData: rideDoc.data() ?? {},
              ),
            ),
          );
        }
      },
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
            // Driver name + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Driver: $driverName",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // From -> To
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

            // Date, Time, Price
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
            const SizedBox(height: 12),

            // View Details button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Fetch the full ride data and navigate
                  final rideDoc = await FirebaseFirestore.instance
                      .collection('rides')
                      .doc(rideId)
                      .get();
                  
                  if (rideDoc.exists && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PassengerRideDetailsScreen(
                          rideId: rideId,
                          rideData: rideDoc.data() ?? {},
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('View Ride Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kUniRideTeal2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelRide(String rideId) async {
    try {
      await FirebaseFirestore.instance.collection("rides").doc(rideId).update({
        "status": "cancelled",
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ride canceled.")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error canceling ride: $e")));
    }
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
