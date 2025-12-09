import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'driver_ride_details_screen.dart';
import 'passenger_ride_details_screen.dart';
import 'chat_screen.dart';
import 'incoming_ride_requests_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color kScreenTeal = Color(0xFFE0F9FB);
  static const Color kUniRideTeal2 = Color(0xFF009DAE);
  static const Color kUniRideYellow = Color(0xFFFFC727);

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
    // Error handling: silently catch to prevent crashes
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'ride_request':
        return Icons.directions_car;
      case 'ride_accepted':
        return Icons.check_circle;
      case 'ride_declined':
        return Icons.cancel;
      case 'ride_cancelled':
        return Icons.event_busy;
      case 'request_cancelled':
        return Icons.event_busy;
      case 'chat_message':
        return Icons.chat_bubble;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'ride_accepted':
        return Colors.green;
      case 'ride_declined':
      case 'ride_cancelled':
      case 'request_cancelled':
        return Colors.red;
      case 'chat_message':
        return kUniRideTeal2;
      default:
        return kUniRideYellow;
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['type'] as String?;
    final data = notification;

    try {
      switch (type) {
        case 'chat_message':
          final chatRoomId = data['chatRoomId'];
          final senderId = data['senderId'];
          final senderName = data['senderName'] ?? 'User';
          if (chatRoomId != null && senderId != null) {
            Navigator.push(
              context,
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
          // Driver receives ride requests - navigate to incoming requests screen
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const IncomingRideRequestsScreen(),
              ),
            );
          }
          break;

        case 'request_cancelled':
          // Navigate to driver ride details for cancellation
          final rideId = data['rideId'];
          if (rideId != null) {
            final rideDoc = await FirebaseFirestore.instance
                .collection('rides')
                .doc(rideId)
                .get();
            if (rideDoc.exists && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverRideDetailsScreen(
                    rideId: rideId,
                    rideData: rideDoc.data()!,
                  ),
                ),
              );
            }
          }
          break;

        case 'ride_accepted':
        case 'ride_declined':
        case 'ride_cancelled':
          // Passenger receives these - navigate to passenger ride details
          final rideId = data['rideId'];
          if (rideId != null) {
            final rideDoc = await FirebaseFirestore.instance
                .collection('rides')
                .doc(rideId)
                .get();
            if (rideDoc.exists && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PassengerRideDetailsScreen(
                    rideId: rideId,
                    rideData: rideDoc.data()!,
                  ),
                ),
              );
            }
          }
          break;
      }
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening notification: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kScreenTeal,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: kUniRideTeal2,
          ),
        ),
        backgroundColor: kScreenTeal,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kUniRideTeal2),
      ),
      body: user == null
          ? const Center(
              child: Text('Please sign in to view notifications'),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kUniRideTeal2),
                  );
                }

                // Get notifications and sort in memory to avoid index requirement
                final notifications = snapshot.data?.docs ?? [];
                notifications.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime); // descending order
                });
                
                // Limit to 50 most recent
                final limitedNotifications = notifications.take(50).toList();

                if (limitedNotifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 80,
                          color: kUniRideTeal2.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kUniRideTeal2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll see ride updates and messages here',
                          style: TextStyle(
                            fontSize: 14,
                            color: kUniRideTeal2.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                  color: kUniRideTeal2,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: limitedNotifications.length,
                    itemBuilder: (context, index) {
                      final doc = limitedNotifications[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data['type'] as String? ?? '';
                      final title = data['title'] as String? ?? 'Notification';
                      final body = data['body'] as String? ?? '';
                      final timestamp = data['createdAt'] as Timestamp?;
                      final isRead = data['read'] as bool? ?? false;

                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        onDismissed: (direction) async {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(doc.id)
                              .delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notification deleted'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isRead
                                ? Colors.white
                                : kUniRideTeal2.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRead
                                  ? Colors.grey.shade200
                                  : kUniRideTeal2.withValues(alpha: 0.2),
                              width: isRead ? 1 : 2,
                            ),
                          ),
                          child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: _getColorForType(type).withValues(alpha: 0.2),
                            child: Icon(
                              _getIconForType(type),
                              color: _getColorForType(type),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _formatTimestamp(timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                            ),
                          ),
                            onTap: () => _handleNotificationTap(data),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
