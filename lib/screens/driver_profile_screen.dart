import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/rating_service.dart';

const Color kUniRideTeal1 = Color(0xFF00BCC9);
const Color kUniRideTeal2 = Color(0xFF009DAE);
const Color kScreenTeal = Color(0xFFE0F9FB);

class DriverProfileScreen extends StatefulWidget {
  final String driverId;
  final String driverName;

  const DriverProfileScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _getDriverInfo() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.driverId)
          .get();
      return doc.data() ?? {};
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return {};
    }
  }

  Future<Map<String, dynamic>> _getVehicleInfo() async {
    try {
      final querySnapshot = await _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: widget.driverId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return {};
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScreenTeal,
      appBar: AppBar(
        backgroundColor: kScreenTeal,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kUniRideTeal2),
        title: const Text(
          "Driver Profile",
          style: TextStyle(
            color: kUniRideTeal2,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getDriverInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kUniRideTeal2),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading driver info',
                style: TextStyle(color: Colors.red.shade600),
              ),
            );
          }

          final driverData = snapshot.data ?? {};

          return FutureBuilder<Map<String, dynamic>>(
            future: _getVehicleInfo(),
            builder: (context, vehicleSnapshot) {
              final vehicleData = vehicleSnapshot.data ?? {};

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDriverHeaderCard(driverData),
                      const SizedBox(height: 20),
                      _buildCarInfoCard(vehicleData),
                      const SizedBox(height: 20),
                      _buildRatingCard(),
                      const SizedBox(height: 20),
                      _buildPreviousRatings(),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDriverHeaderCard(Map<String, dynamic> driverData) {
    final name = driverData['name'] as String? ?? widget.driverName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: kUniRideTeal2,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCarInfoCard(Map<String, dynamic> vehicleData) {
    final carMake = vehicleData['make'] as String? ?? '';
    final carModel = vehicleData['model'] as String? ?? '';
    final carColor = vehicleData['color'] as String? ?? '';
    final carPlate = vehicleData['licensePlate'] as String? ?? '';

    final fullCarName = carModel.isNotEmpty ? '$carMake $carModel' : carMake;

    // Check if any vehicle info is filled
    final hasVehicleInfo =
        fullCarName.isNotEmpty || carColor.isNotEmpty || carPlate.isNotEmpty;

    if (!hasVehicleInfo) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vehicle Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No vehicle information provided',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (fullCarName.isNotEmpty) ...[
            _buildCarDetailRow('Car', fullCarName),
            const SizedBox(height: 12),
          ],
          if (carColor.isNotEmpty) ...[
            _buildCarDetailRow('Color', carColor),
            const SizedBox(height: 12),
          ],
          if (carPlate.isNotEmpty) _buildCarDetailRow('Plate Number', carPlate),
        ],
      ),
    );
  }

  Widget _buildCarDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingCard() {
    return FutureBuilder<double>(
      future: RatingService.getAverageRating(widget.driverId),
      builder: (context, snapshot) {
        final avgRating = snapshot.data ?? 0.0;

        return FutureBuilder<int>(
          future: RatingService.getRatingCount(widget.driverId),
          builder: (context, countSnapshot) {
            final count = countSnapshot.data ?? 0;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Average Rating',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: kUniRideTeal2,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kScreenTeal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.star,
                          color: kUniRideTeal2,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$count ${count == 1 ? 'rating' : 'ratings'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviousRatings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Previous Ratings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: RatingService.getRatingsWithComments(widget.driverId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kUniRideTeal2),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading ratings',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              );
            }

            final ratings = snapshot.data ?? [];

            if (ratings.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'No ratings yet',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ratings.length,
              itemBuilder: (context, index) {
                final rating = ratings[index];
                final score = rating['score'] as int;
                final comment = rating['comment'] as String;
                final ratedBy = rating['ratedBy'] as String;
                final stars = '⭐' * score;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0) const Divider(height: 16, thickness: 1),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String>(
                            future: _getRaterName(ratedBy),
                            builder: (context, nameSnapshot) {
                              final raterName =
                                  nameSnapshot.data ?? 'Anonymous';
                              return Text(
                                'From $raterName',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(stars, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                '$score.0 star${score != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kScreenTeal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                comment,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<String> _getRaterName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['name'] as String? ?? 'Anonymous';
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
    return 'Anonymous';
  }
}
