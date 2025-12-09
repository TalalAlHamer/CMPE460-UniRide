import 'package:flutter/material.dart';

class RideRequestsScreen extends StatelessWidget {
  final String from;
  final String to;
  final String day;
  final String time;
  final String price;
  final int requests;

  const RideRequestsScreen({
    super.key,
    required this.from,
    required this.to,
    required this.day,
    required this.time,
    required this.price,
    required this.requests,
  });

  static const Color kScreenTeal = Color(0xFFE0F9FB);
  static const Color kUniRideTeal2 = Color(0xFF009DAE);

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
          "Ride Requests",
          style: TextStyle(
            color: kUniRideTeal2,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          "Requests will appear here",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
