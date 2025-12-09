import 'package:cloud_firestore/cloud_firestore.dart';

class RideCleanupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Deletes all rides and associated ride requests that are 8+ hours past their scheduled time
  static Future<void> deleteExpiredRides() async {
    try {
      final now = DateTime.now();

      // Get all rides
      final ridesSnapshot = await _firestore.collection('rides').get();

      for (final doc in ridesSnapshot.docs) {
        final data = doc.data();
        final date = data['date'] as String?;
        final time = data['time'] as String?;

        if (date != null && time != null) {
          final rideDateTime = _parseDateTime(date, time);
          final hoursSinceRide = now.difference(rideDateTime).inHours;

          // If ride is 8+ hours past, delete it
          if (hoursSinceRide >= 8) {
            // Delete associated ride requests from subcollection
            final requestsSnapshot = await _firestore
                .collection('rides')
                .doc(doc.id)
                .collection('requests')
                .get();

            for (final requestDoc in requestsSnapshot.docs) {
              await requestDoc.reference.delete();
            }

            // Delete the ride
            await doc.reference.delete();
          }
        }
      }
    } catch (e) {
      print('Error deleting expired rides: $e');
    }
  }

  /// Parse date (DD/MM/YYYY) and time (HH:mm AM/PM) strings into DateTime
  static DateTime _parseDateTime(String date, String time) {
    try {
      final dateParts = date.split('/');
      if (dateParts.length != 3) return DateTime.now();

      // Parse time with AM/PM
      final timeUpper = time.toUpperCase();
      final isPM = timeUpper.contains('PM');
      final timeOnly = timeUpper
          .replaceAll('AM', '')
          .replaceAll('PM', '')
          .trim();
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

  /// Call this method periodically or on app startup to clean up old rides
  static Future<void> scheduleCleanup() async {
    // Run cleanup immediately on app start
    await deleteExpiredRides();

    // You could also set up a periodic timer here if needed
    // For example, run cleanup every hour:
    // Timer.periodic(const Duration(hours: 1), (_) => deleteExpiredRides());
  }
}
