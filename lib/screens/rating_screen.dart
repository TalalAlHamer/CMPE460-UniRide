import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingScreen extends StatefulWidget {
  final String rideId;
  final bool isDriver; // true if current user is driver, false if passenger
  final List<Map<String, dynamic>>
  usersToRate; // List of {userId, name} to rate

  const RatingScreen({
    super.key,
    required this.rideId,
    required this.isDriver,
    required this.usersToRate,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  static const Color kScreenTeal = Color(0xFFE0F9FB);
  static const Color kUniRideTeal2 = Color(0xFF009DAE);
  static const Color kUniRideYellow = Color(0xFFFFC727);

  late Map<String, int> ratings; // Map of userId -> rating score
  late Map<String, String> comments; // Map of userId -> comment
  late Map<String, TextEditingController> commentControllers;
  int currentIndex = 0;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize ratings map with 0 for each user
    ratings = {for (var user in widget.usersToRate) user['userId']: 0};
    // Initialize comments map
    comments = {for (var user in widget.usersToRate) user['userId']: ''};
    // Initialize text controllers for comments
    commentControllers = {
      for (var user in widget.usersToRate)
        user['userId']: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (var controller in commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitRatings() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Check that all users have been rated
    if (ratings.values.any((score) => score == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate all passengers/driver'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final ratingsCollection = FirebaseFirestore.instance.collection(
        'ratings',
      );

      // Add rating for each user
      for (final entry in ratings.entries) {
        final ratedUserId = entry.key;
        final score = entry.value;
        final comment = comments[ratedUserId] ?? '';

        // Check if rating already exists for this ride and user
        final existingRating = await ratingsCollection
            .where('rideId', isEqualTo: widget.rideId)
            .where('ratedBy', isEqualTo: currentUser.uid)
            .where('ratedUserId', isEqualTo: ratedUserId)
            .get();

        if (existingRating.docs.isEmpty) {
          // Create new rating document
          final ratingDoc = ratingsCollection.doc();
          batch.set(ratingDoc, {
            'rideId': widget.rideId,
            'ratedBy': currentUser.uid,
            'ratedUserId': ratedUserId,
            'score': score,
            'comment': comment,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Note: Ride and request status are already marked as completed when the ride was completed
      // We don't need to update them again here to avoid duplicate updates

      await batch.commit();

      // Note: Notifications are sent automatically by Cloud Function (onRatingReceived)
      // when a rating document is created in Firestore.
      // The Cloud Function handles:
      // - Sending FCM push notification
      // - Creating notification document in notifications collection

      if (mounted) {
        // Close and navigate back with success result
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ratings submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting ratings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usersToRate.isEmpty) {
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
            "Rate Ride",
            style: TextStyle(
              color: kUniRideTeal2,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'No users to rate for this ride',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
      );
    }

    final currentUserToRate = widget.usersToRate[currentIndex];
    final currentUserId = currentUserToRate['userId'] as String;
    final currentUserName = currentUserToRate['name'] as String;
    final currentRating = ratings[currentUserId] ?? 0;

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
          "Rate Ride",
          style: TextStyle(
            color: kUniRideTeal2,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // Progress indicator
            Text(
              '${currentIndex + 1} of ${widget.usersToRate.length}',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // User to rate
            Text(
              'Rate $currentUserName',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Star rating
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          ratings[currentUserId] = index + 1;
                        });
                      },
                      child: Icon(
                        index < currentRating ? Icons.star : Icons.star_border,
                        color: kUniRideYellow,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Rating display
            Text(
              currentRating == 0
                  ? 'Select a rating'
                  : '$currentRating star${currentRating != 1 ? 's' : ''}',
              style: TextStyle(
                color: currentRating == 0 ? Colors.grey : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 24),

            // Comment section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add a comment (optional)',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: commentControllers[currentUserId],
              maxLines: 3,
              maxLength: 200,
              onChanged: (value) {
                comments[currentUserId] = value;
              },
              decoration: InputDecoration(
                hintText: 'Share your thoughts about this ride...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kUniRideTeal2, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                counterStyle: TextStyle(color: Colors.grey[500]),
              ),
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),

            const Spacer(),

            // Navigation and submit buttons
            Row(
              children: [
                if (currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              setState(() => currentIndex--);
                            },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kUniRideTeal2, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Previous',
                        style: TextStyle(
                          color: kUniRideTeal2,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                if (currentIndex > 0) const SizedBox(width: 12),
                Expanded(
                  child: currentIndex < widget.usersToRate.length - 1
                      ? ElevatedButton(
                          onPressed: isSubmitting || currentRating == 0
                              ? null
                              : () {
                                  setState(() => currentIndex++);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kUniRideYellow,
                            disabledBackgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: isSubmitting ? null : _submitRatings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kUniRideYellow,
                            disabledBackgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black87,
                                  ),
                                )
                              : const Text(
                                  'Submit Ratings',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
