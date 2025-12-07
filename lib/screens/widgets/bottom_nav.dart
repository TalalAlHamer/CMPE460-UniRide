import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';
import '../my_rides_screen.dart';
import '../profile_screen.dart';

// Cache the pending count stream to prevent rebuilds
class _PendingRequestsCache {
  static Stream<int>? _cachedStream;
  static String? _cachedUserId;

  static Stream<int> getStream(String userId) {
    // Return cached stream if it exists for the same user
    if (_cachedStream != null && _cachedUserId == userId) {
      return _cachedStream!;
    }

    // Create new stream that listens to both rides and requests in real-time
    _cachedUserId = userId;
    _cachedStream = FirebaseFirestore.instance
        .collection('rides')
        .where('driverId', isEqualTo: userId)
        .snapshots()
        .asyncMap((ridesSnapshot) async {
      if (ridesSnapshot.docs.isEmpty) return 0;

      final userRideIds = ridesSnapshot.docs.map((doc) => doc.id).toList();
      
      // Use snapshots() instead of get() for real-time updates
      int totalPending = 0;
      
      // Query pending requests for each ride using snapshots for real-time
      for (final rideId in userRideIds) {
        final pendingCount = await FirebaseFirestore.instance
            .collection('rides')
            .doc(rideId)
            .collection('requests')
            .where('status', isEqualTo: 'pending')
            .get()
            .then((snapshot) => snapshot.docs.length);
        
        totalPending += pendingCount;
      }

      return totalPending;
    });

    return _cachedStream!;
  }
}

class BottomNav extends StatefulWidget {
  final int currentIndex;

  const BottomNav({super.key, required this.currentIndex});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      selectedItemColor: Colors.teal,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      elevation: 8,

      onTap: (index) {
        if (index == widget.currentIndex) return;

        Widget? targetScreen;
        switch (index) {
          case 0:
            targetScreen = _getScreen('/home');
            break;
          case 1:
            targetScreen = _getScreen('/my-rides');
            break;
          case 2:
            targetScreen = _getScreen('/profile');
            break;
        }

        if (targetScreen != null) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => targetScreen!,
              transitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            ),
          );
        }
      },

      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        const BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: "My Rides"),
        BottomNavigationBarItem(
          icon: _buildProfileIcon(),
          label: "Profile",
        ),
      ],
    );
  }

  Widget? _getScreen(String route) {
    switch (route) {
      case '/home':
        return const HomeScreen();
      case '/my-rides':
        return const MyRidesScreen();
      case '/profile':
        return const ProfileScreen();
      default:
        return null;
    }
  }

  Widget _buildProfileIcon() {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return const Icon(Icons.person);
    }

    return StreamBuilder<int>(
      stream: _PendingRequestsCache.getStream(currentUser.uid),
      builder: (context, snapshot) {
        final totalPending = snapshot.data ?? 0;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.person),
            if (totalPending > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    totalPending > 99 ? '99+' : '$totalPending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Don't clear cache here - let it persist across navigations
    super.dispose();
  }
}