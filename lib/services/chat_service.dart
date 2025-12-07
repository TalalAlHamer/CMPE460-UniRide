import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/chat_room.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create or get existing chat room between two users for a specific ride
  static Future<String> createOrGetChatRoom({
    required String otherUserId,
    required String otherUserName,
    String? rideId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    // Create ride-specific chat room ID to isolate message history per ride
    final participantIds = [currentUser.uid, otherUserId]..sort();
    final chatRoomId = rideId != null 
        ? '${participantIds.join('_')}_$rideId'
        : participantIds.join('_');

    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final chatRoomDoc = await chatRoomRef.get();

    if (!chatRoomDoc.exists) {
      // Get current user's name
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final currentUserName = userDoc.data()?['name'] ?? 'User';

      // Create new chat room
      await chatRoomRef.set({
        'participantIds': participantIds,
        'participantNames': {
          currentUser.uid: currentUserName,
          otherUserId: otherUserName,
        },
        'rideId': rideId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {
          currentUser.uid: 0,
          otherUserId: 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return chatRoomId;
  }

  /// Send a message
  static Future<void> sendMessage({
    required String chatRoomId,
    required String text,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    if (text.trim().isEmpty) return;

    // Get current user's name
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final senderName = userDoc.data()?['name'] ?? 'User';

    // Get chat room to find the other participant
    final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
    final participantIds = List<String>.from(chatRoomDoc.data()?['participantIds'] ?? []);
    final otherUserId = participantIds.firstWhere((id) => id != currentUser.uid);

    final batch = _firestore.batch();

    // Add message
    final messageRef = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc();

    batch.set(messageRef, {
      'chatId': chatRoomId,
      'senderId': currentUser.uid,
      'senderName': senderName,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Update chat room
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    batch.update(chatRoomRef, {
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });

    await batch.commit();

    // Trigger notification via Cloud Function by creating a notification document
    await _firestore.collection('notifications').add({
      'recipientId': otherUserId,
      'senderId': currentUser.uid,
      'senderName': senderName,
      'title': 'New message from $senderName',
      'body': text.trim().length > 50 ? '${text.trim().substring(0, 50)}...' : text.trim(),
      'type': 'chat_message',
      'chatRoomId': chatRoomId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get messages stream
  static Stream<List<Message>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  /// Get chat rooms stream for current user
  static Stream<List<ChatRoom>> getChatRooms() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chatRooms')
        .where('participantIds', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      // Sort in memory instead of using Firestore orderBy to avoid index requirement
      final chatRooms = snapshot.docs
          .map((doc) => ChatRoom.fromFirestore(doc))
          .toList();
      
      chatRooms.sort((a, b) {
        final aTime = a.lastMessageTime.toDate();
        final bTime = b.lastMessageTime.toDate();
        return bTime.compareTo(aTime); // descending order
      });
      
      return chatRooms;
    });
  }

  /// Mark messages as read
  static Future<void> markMessagesAsRead(String chatRoomId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();

    // Get unread messages
    final unreadMessages = await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .get();

    // Mark each message as read
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Reset unread count for current user
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    batch.update(chatRoomRef, {
      'unreadCount.${currentUser.uid}': 0,
    });

    await batch.commit();
  }

  /// Get total unread count for current user
  static Stream<int> getTotalUnreadCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('chatRooms')
        .where('participantIds', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
        total += (unreadCount?[currentUser.uid] as int?) ?? 0;
      }
      return total;
    });
  }

  /// Delete a chat room
  static Future<void> deleteChatRoom(String chatRoomId) async {
    final batch = _firestore.batch();

    // Delete all messages
    final messages = await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .get();

    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete chat room
    batch.delete(_firestore.collection('chatRooms').doc(chatRoomId));

    await batch.commit();
  }
}
