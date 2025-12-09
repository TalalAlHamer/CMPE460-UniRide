import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/chat_screen.dart';
import '../screens/driver_ride_details_screen.dart';
import '../screens/passenger_ride_details_screen.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize FCM and local notifications
  static Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    }

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Get and save FCM token
    await _saveFCMToken();

    // Listen to token refresh
    _messaging.onTokenRefresh.listen(_updateFCMToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  /// Save FCM token to Firestore
  static Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // For iOS, wait for APNs token to be available
      if (Platform.isIOS) {
        await Future.delayed(const Duration(seconds: 2));
      }

      final token = await _messaging.getToken();
      if (token == null) {
        return;
      }

      // Use set with merge to ensure field is created/updated
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
    // Error handling: silently catch to prevent crashes

      // For iOS APNs token error, retry after delay
      if (e.toString().contains('apns-token-not-set') && Platform.isIOS) {
      }
    }
  }

  /// Update FCM token on refresh
  static Future<void> _updateFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Use set with merge to ensure field is created/updated
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
  }

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {

    // Show local notification when app is in foreground
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'uniride_channel',
          'UniRide Notifications',
          channelDescription: 'Notifications for ride updates and messages',
          importance: Importance.high,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'UniRide',
      message.notification?.body ?? '',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap (background)
  static void _handleNotificationTap(RemoteMessage message) {
    _navigateBasedOnNotification(message.data);
  }

  /// Handle local notification tap (foreground)
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateBasedOnNotification(data);
      } catch (e) {
    // Error handling: silently catch to prevent crashes
      }
    }
  }

  /// Navigate to appropriate screen based on notification type
  static void _navigateBasedOnNotification(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final type = data['type'];

    // Delay to ensure UI is ready
    Future.delayed(const Duration(milliseconds: 300), () {
      switch (type) {
        case 'chat_message':
          final chatRoomId = data['chatRoomId'];
          final senderId = data['senderId'];
          final senderName = data['senderName'] ?? 'User';
          if (chatRoomId != null && senderId != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatRoomId: chatRoomId,
                  otherUserId: senderId,
                  otherUserName: senderName,
                ),
              ),
            );
          }
          break;

        case 'ride_request':
        case 'request_cancelled':
          // Driver receives these - navigate to driver ride details
          final rideId = data['rideId'];
          if (rideId != null) {
            _navigateToDriverRideDetails(rideId);
          }
          break;

        case 'ride_accepted':
        case 'ride_declined':
        case 'ride_cancelled':
          // Passenger receives these - navigate to passenger ride details
          final rideId = data['rideId'];
          if (rideId != null) {
            _navigateToPassengerRideDetails(rideId);
          }
          break;

        case 'rating_comment':
          // User receives comment on their rating - navigate to driver or passenger ride details
          final rideId = data['rideId'];
          if (rideId != null) {
            // We navigate to the ride details - the app will determine if it's driver or passenger view
            _navigateToRideDetailsFromRating(rideId);
          }
          break;

        default:
          break;
      }
    });
  }

  /// Navigate to ride details (handles both driver and passenger views)
  static Future<void> _navigateToRideDetailsFromRating(String rideId) async {
    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .get();

      if (rideDoc.exists) {
        final rideData = rideDoc.data()!;
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser == null) return;

        // Check if current user is the driver or a passenger
        if (rideData['driverId'] == currentUser.uid) {
          // Current user is driver
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) =>
                  DriverRideDetailsScreen(rideId: rideId, rideData: rideData),
            ),
          );
        } else {
          // Current user is passenger
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => PassengerRideDetailsScreen(
                rideId: rideId,
                rideData: rideData,
              ),
            ),
          );
        }
      } else {
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
  }

  /// Fetch ride data and navigate to driver ride details
  static Future<void> _navigateToDriverRideDetails(String rideId) async {
    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .get();

      if (rideDoc.exists) {
        final rideData = rideDoc.data()!;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                DriverRideDetailsScreen(rideId: rideId, rideData: rideData),
          ),
        );
      } else {
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
  }

  /// Fetch ride data and navigate to passenger ride details
  static Future<void> _navigateToPassengerRideDetails(String rideId) async {
    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .get();

      if (rideDoc.exists) {
        final rideData = rideDoc.data()!;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                PassengerRideDetailsScreen(rideId: rideId, rideData: rideData),
          ),
        );
      } else {
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
  }

  /// Send notification via Cloud Function
  static Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    Map<String, String>? data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
  }

  /// Delete FCM token on logout
  static Future<void> deleteFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': FieldValue.delete()},
      );

      await _messaging.deleteToken();
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
  }
}
