import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/bottom_nav.dart';
import 'my_rides_screen.dart';
import 'incoming_ride_requests_screen.dart';
import 'driver_vehicles_screen.dart';
import 'package:uniride_app/services/rating_service.dart';
import 'package:uniride_app/services/notification_service.dart';

// COLORS
const Color kScreenTeal = Color(0xFFE0F9FB);
const Color kUniRideTeal2 = Color(0xFF009DAE);
const Color kUniRideTeal1 = Color(0xFF00BCC9);
const Color kUniRideYellow = Color(0xFFFFC727);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      return {
        "uid": user.uid,
        "name": user.displayName ?? "UniRide user",
        "email": user.email ?? "",
        "phone": "",
        "createdAt": null,
      };
    }

    final data = doc.data()!;
    data["uid"] = user.uid;
    return data;
  }

  void _logout() async {
    // Delete FCM token before signing out
    await NotificationService.deleteFCMToken();
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  void _editProfile(String currentName, String currentPhone) async {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(
      text: currentPhone == "Not set" ? "" : currentPhone,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Name",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: "Phone Number",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user != null) {
                await user.updateDisplayName(nameController.text);

                await _firestore.collection('users').doc(user.uid).set({
                  "name": nameController.text,
                  "phone": phoneController.text,
                  "email": user.email,
                  "uid": user.uid,
                  "updatedAt": FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Profile updated")),
                );

                setState(() => _profileFuture = _loadProfile());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kUniRideTeal2,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<String> _getRaterName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['name'] as String? ?? 'Unknown User';
      }
    } catch (e) {
      print('Error fetching rater name: $e');
    }
    return 'Unknown User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScreenTeal,
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: kUniRideTeal2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: kScreenTeal,
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: kUniRideTeal2),
            );
          }

          final data = snapshot.data!;
          final name = data["name"] ?? "UniRide User";
          final email = data["email"] ?? "";
          final phone = (data["phone"] ?? "").isEmpty
              ? "Not set"
              : data["phone"];
          final role = data["role"] ?? "Student rider & driver";

          String memberSince = "Not available";
          if (data["createdAt"] is Timestamp) {
            final dt = (data["createdAt"] as Timestamp).toDate();
            memberSince = "${dt.day}/${dt.month}/${dt.year}";
          }

          final initials = name.isNotEmpty ? name[0].toUpperCase() : "U";

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _profileFuture = _loadProfile();
              });
              await _profileFuture;
            },
            color: kUniRideTeal2,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  // HEADER CARD
                  _WhiteCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: kUniRideTeal1.withOpacity(0.15),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: kUniRideTeal2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user,
                                    size: 16,
                                    color: kUniRideTeal2,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    role,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _editProfile(name, phone),
                          icon: const Icon(Icons.edit, color: kUniRideTeal2),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ACCOUNT DETAILS CARD
                  _WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Account details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailRow(
                          icon: Icons.directions_car,
                          label: "Total rides",
                          value: (data["totalRides"] ?? 0).toString(),
                        ),
                        FutureBuilder<String>(
                          future: RatingService.getRatingDisplay(data["uid"]),
                          builder: (context, snap) {
                            return _DetailRow(
                              icon: Icons.star,
                              label: "Rating",
                              value: snap.data ?? "—",
                            );
                          },
                        ),
                        _DetailRow(
                          icon: Icons.phone,
                          label: "Phone",
                          value: phone,
                        ),
                        _DetailRow(
                          icon: Icons.calendar_today,
                          label: "Member since",
                          value: memberSince,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // RATINGS AND COMMENTS
                  _WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Ratings & Comments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: RatingService.getRatingsWithComments(
                            data["uid"],
                          ),
                          builder: (context, snapshot) {
                            // Handle loading state
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            // Handle error state
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'Error loading ratings',
                                    style: TextStyle(
                                      color: Colors.red[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final ratings = snapshot.data ?? [];

                            if (ratings.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'When somebody rates you, it will show here',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
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
                                    if (index > 0)
                                      const Divider(height: 20, thickness: 1),
                                    FutureBuilder<String>(
                                      future: _getRaterName(ratedBy),
                                      builder: (context, nameSnapshot) {
                                        final raterName =
                                            nameSnapshot.data ?? 'Unknown User';
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'From $raterName',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Text(
                                                  stars,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                ),
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
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: kScreenTeal,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // LINKS
                  _WhiteCard(
                    child: Column(
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collectionGroup('requests')
                              .where('driverId', isEqualTo: data["uid"])
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, requestsSnapshot) {
                            final pendingCount = requestsSnapshot.hasData
                                ? requestsSnapshot.data!.docs.length
                                : 0;

                            return _LinkTileWithBadge(
                              icon: Icons.group_add,
                              label: "Incoming Ride Requests",
                              badgeCount: pendingCount,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const IncomingRideRequestsScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _LinkTile(
                          icon: Icons.directions_car,
                          label: "My rides",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyRidesScreen(),
                            ),
                          ),
                        ),
                        const Divider(),
                        _LinkTile(
                          icon: Icons.garage,
                          label: "Vehicles",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverVehiclesScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // LOGOUT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kUniRideTeal2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "Log out",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===================== REUSABLE WIDGETS =========================

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: kUniRideTeal2, size: 20),
          const SizedBox(width: 10),
          Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: kUniRideTeal2, size: 26),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black38),
      onTap: onTap,
    );
  }
}

class _LinkTileWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _LinkTileWithBadge({
    required this.icon,
    required this.label,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: kUniRideTeal2, size: 26),
          if (badgeCount > 0)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
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
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black38),
      onTap: onTap,
    );
  }
}
