import 'package:cloud_firestore/cloud_firestore.dart';

class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get average rating for a user
  static Future<double> getAverageRating(String userId) async {
    try {
      final query = await _firestore
          .collection('ratings')
          .where('ratedUserId', isEqualTo: userId)
          .get();

      if (query.docs.isEmpty) {
        return 0.0;
      }

      final total = query.docs.fold<int>(
        0,
        (acc, doc) => acc + (doc['rating'] as int? ?? 0),
      );

      return total / query.docs.length;
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return 0.0;
    }
  }

  /// Get rating count for a user
  static Future<int> getRatingCount(String userId) async {
    try {
      final query = await _firestore
          .collection('ratings')
          .where('ratedUserId', isEqualTo: userId)
          .get();

      return query.docs.length;
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return 0;
    }
  }

  /// Get both average rating and count as a combined string
  static Future<String> getRatingDisplay(String userId) async {
    try {
      final query = await _firestore
          .collection('ratings')
          .where('ratedUserId', isEqualTo: userId)
          .get();

      if (query.docs.isEmpty) {
        return "No ratings yet";
      }

      final total = query.docs.fold<int>(
        0,
        (acc, doc) => acc + (doc['score'] as int? ?? 0),
      );

      final average = total / query.docs.length;
      final count = query.docs.length;

      return "${average.toStringAsFixed(1)} ⭐ ($count rating${count != 1 ? 's' : ''})";
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return "No ratings yet";
    }
  }

  /// Get rating as a stream for real-time updates
  static Stream<double> getRatingStream(String userId) {
    return _firestore
        .collection('ratings')
        .where('ratedUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return 0.0;
          }

          final total = snapshot.docs.fold<int>(
            0,
            (acc, doc) => acc + (doc['score'] as int? ?? 0),
          );

          return total / snapshot.docs.length;
        });
  }

  /// Check if user has already rated another user for a specific ride
  static Future<bool> hasRated(
    String riderUserId,
    String ratedUserId,
    String rideId,
  ) async {
    try {
      final query = await _firestore
          .collection('ratings')
          .where('rideId', isEqualTo: rideId)
          .where('ratedBy', isEqualTo: riderUserId)
          .where('ratedUserId', isEqualTo: ratedUserId)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return false;
    }
  }

  /// Get all ratings with comments for a user
  static Stream<List<Map<String, dynamic>>> getRatingsWithComments(
    String userId,
  ) {
    return _firestore
        .collection('ratings')
        .where('ratedUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          // Sort in Dart instead of requiring a Firestore index
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final aCreated = a['createdAt'] as dynamic;
            final bCreated = b['createdAt'] as dynamic;

            // Handle null values
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;

            // Assuming createdAt is a Timestamp
            return bCreated.compareTo(aCreated);
          });

          return docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'score': data['score'] as int? ?? 0,
              'comment': data['comment'] as String? ?? '',
              'createdAt': data['createdAt'],
              'ratedBy': data['ratedBy'] as String? ?? '',
            };
          }).toList();
        });
  }
}
