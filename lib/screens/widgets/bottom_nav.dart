import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';
import '../my_rides_screen.dart';
import '../profile_screen.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;

  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.teal,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      elevation: 8,

      onTap: (index) {
        if (index == currentIndex) return;

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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, ridesSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, requestsSnapshot) {
            int totalPending = 0;
            
            if (requestsSnapshot.hasData && ridesSnapshot.hasData) {
              final userRideIds = ridesSnapshot.data!.docs.map((doc) => doc.id).toList();
              
              for (var requestDoc in requestsSnapshot.data!.docs) {
                final rideId = requestDoc.reference.parent.parent?.id;
                if (rideId != null && userRideIds.contains(rideId)) {
                  totalPending++;
                }
              }
            }
            
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
      },
    );
  }
}