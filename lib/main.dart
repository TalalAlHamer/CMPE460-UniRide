import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/driver_offer_ride_screen.dart';
import 'screens/passenger_find_ride_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/driver_ride_details_screen.dart';
import 'screens/passenger_ride_details_screen.dart';
import 'screens/chat_screen.dart';

// Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service when user is logged in
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      NotificationService.initialize();
    }
  });

  // Handle notification that opened the app from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null && FirebaseAuth.instance.currentUser != null) {
      _handleNotificationNavigation(message.data);
    }
  });

  // Handle notification tap when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    if (FirebaseAuth.instance.currentUser != null) {
      _handleNotificationNavigation(message.data);
    }
  });

  runApp(const UniRideApp());
}

// Handle navigation based on notification data
void _handleNotificationNavigation(Map<String, dynamic> data) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  final type = data['type'];

  // Delay navigation to ensure app is fully loaded
  Future.delayed(const Duration(milliseconds: 500), () {
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

      default:
        // Unknown notification type, do nothing
        break;
    }
  });
}

// Fetch ride data and navigate to driver ride details
Future<void> _navigateToDriverRideDetails(String rideId) async {
  try {
    final rideDoc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .get();

    if (rideDoc.exists) {
      final rideData = rideDoc.data()!;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => DriverRideDetailsScreen(
            rideId: rideId,
            rideData: rideData,
          ),
        ),
      );
    } else {
      // No ride document found
    }
  } catch (e) {
    // Error handling: silently catch to prevent crashes
    // Silently handle navigation errors
  }
}

// Fetch ride data and navigate to passenger ride details
Future<void> _navigateToPassengerRideDetails(String rideId) async {
  try {
    final rideDoc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .get();

    if (rideDoc.exists) {
      final rideData = rideDoc.data()!;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => PassengerRideDetailsScreen(
            rideId: rideId,
            rideData: rideData,
          ),
        ),
      );
    } else {
      // No ride document found
    }
  } catch (e) {
    // Error handling: silently catch to prevent crashes
    // Silently handle navigation errors
  }
}

class UniRideApp extends StatelessWidget {
  const UniRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: const Color(0xFF009DAE),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009DAE),
          primary: const Color(0xFF009DAE),
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF009DAE), width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/find-ride': (context) => const PassengerFindRideScreen(),
        '/offer-ride': (context) => const DriverOfferRideScreen(),
        '/profile': (context) => const ProfileScreen(),
      },

      initialRoute: '/',
    );
  }
}
