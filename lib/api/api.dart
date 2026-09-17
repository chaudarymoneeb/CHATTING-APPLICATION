// lib/api/api.dart

// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:io';

import 'package:chat_app/models/message_model.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Apis {
  const Apis._();

  static late ChatUser me;
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ======================================================================
  // USER LIFECYCLE
  // ======================================================================

  static Future<bool> userExists() async {
    final user = auth.currentUser;
    if (user == null) return false;
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  static Future<void> createUser(User user) async {
    final userDocument = firestore.collection('users').doc(user.uid);

    if ((await userDocument.get()).exists) {
      await userDocument.set({
        'is_online': true,
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final chatUser = ChatUser(
      id: user.uid,
      name: user.displayName ?? 'User',
      email: user.email ?? '',
      image: user.photoURL ?? '',
      about: "Hey! I'm using We Chat",
      isOnline: true,
      lastActive: time,
      pushToken: '',
      createdAt: time,
    );

    await userDocument.set({
      ...chatUser.toJson(),
      'blocked': <String>[],
      'created_at': FieldValue.serverTimestamp(),
      'last_active': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> getCurrentUserDetails() async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final snapshot = await firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (snapshot.exists) {
      me = ChatUser.fromJson(snapshot.data()!, snapshot.id);
    } else {
      await createUser(currentUser);
      final newSnapshot = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      me = ChatUser.fromJson(newSnapshot.data()!, newSnapshot.id);
    }
  }

  static Future<void> setUserOnline(bool isOnline) async {
    final user = auth.currentUser;
    if (user == null) return;

    await firestore.collection('users').doc(user.uid).set({
      'is_online': isOnline,
      'last_active': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    return firestore
        .collection('users')
        .where('id', isNotEqualTo: auth.currentUser?.uid)
        .snapshots();
  }

  // ======================================================================
  // CHAT ID HELPER
  // ======================================================================

  static String _chatConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  static String chatIdFor(String userId1, String userId2) =>
      _chatConversationId(userId1, userId2);

  static CollectionReference<Map<String, dynamic>> _threadRef(
    String otherUserId,
  ) {
    final currentUser = auth.currentUser;
    final chatId = _chatConversationId(currentUser?.uid ?? '', otherUserId);
    return firestore.collection('messages').doc(chatId).collection('thread');
  }

  static DocumentReference<Map<String, dynamic>> _chatDocRef(
    String otherUserId,
  ) {
    final currentUser = auth.currentUser;
    final chatId = _chatConversationId(currentUser?.uid ?? '', otherUserId);
    return firestore.collection('chats').doc(chatId);
  }

  // ======================================================================
  // ✅ NEW: ADD USER (creates empty chat so they show in list)
  // ======================================================================

  /// User ko apni chat list mein add karo — bina message bheje.
  /// `chats/{chatId}` doc create hoga jismein dono participants honge.
  static Future<bool> addUserToChats({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    try {
      final ref = _chatDocRef(otherUserId);
      final snap = await ref.get();

      if (snap.exists) {
        // Pehle se hai — dobara add karne ki zarurat nahi
        return true;
      }

      await ref.set({
        'chatId': _chatConversationId(currentUser.uid, otherUserId),
        'participants': [currentUser.uid, otherUserId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'addedBy': [currentUser.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User added to chat list: $otherUserId');
      return true;
    } catch (e) {
      debugPrint('❌ addUserToChats error: $e');
      return false;
    }
  }

  /// Optional: agar aap chat ko list se hataana chahein (without deleting
  /// messages). Sirf current user ka chat summary remove karta hai.
  static Future<void> removeChatFromList({required String otherUserId}) async {
    try {
      await _chatDocRef(otherUserId).delete();
    } catch (e) {
      debugPrint('removeChatFromList error: $e');
    }
  }

  // ======================================================================
  // MESSAGES — send / stream
  // ======================================================================

  /// Sends a text message or attachment. Also writes/updates the chat
  /// summary so both users see it in their home screen.
  static Future<bool> sendMessage({
    required String receiverId,
    required String messageText,
    String fileType = 'text',
    String fileUrl = '',
    String fileName = '',
  }) async {
    final currentUser = auth.currentUser;
    final isAttachment = fileType != 'text' && fileUrl.isNotEmpty;
    if (currentUser == null) return false;
    if (!isAttachment && messageText.trim().isEmpty) return false;

    if (await hasBlocked(otherUserId: receiverId) ||
        await isBlockedBy(otherUserId: receiverId)) {
      return false;
    }

    final cleanText = messageText.trim();
    final now = DateTime.now();

    final message = Message(
      id: '${now.millisecondsSinceEpoch}_${currentUser.uid}',
      senderId: currentUser.uid,
      receiverId: receiverId,
      text: cleanText,
      timestamp: now,
      messageStatus: 'sent',
      isSynced: true,
      fileType: fileType,
      fileUrl: fileUrl,
      fileName: fileName,
    );

    // 1) Actual message
    await _threadRef(receiverId).doc(message.id).set(message.toFirestore());

    // 2) Chat summary — so both users see it in list
    final preview = isAttachment ? _previewFor(fileType) : cleanText;
    await _upsertChatSummary(
      otherUserId: receiverId,
      lastMessage: preview,
      lastMessageTime: now,
      lastSenderId: currentUser.uid,
    );

    return true;
  }

  static Future<void> _upsertChatSummary({
    required String otherUserId,
    required String lastMessage,
    required DateTime lastMessageTime,
    required String lastSenderId,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final ref = _chatDocRef(otherUserId);

    await ref.set({
      'chatId': _chatConversationId(currentUser.uid, otherUserId),
      'participants': [currentUser.uid, otherUserId],
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastSenderId': lastSenderId,
    }, SetOptions(merge: true));
  }

  static String _previewFor(String fileType) {
    switch (fileType) {
      case 'image':
        return '📷 Photo';
      case 'audio':
        return '🎤 Voice message';
      case 'document':
        return '📄 Document';
      default:
        return '';
    }
  }

  static Stream<List<Message>> getMessagesStream({
    required String currentUserId,
    required String otherUserId,
  }) {
    final chatId = _chatConversationId(currentUserId, otherUserId);

    return firestore
        .collection('messages')
        .doc(chatId)
        .collection('thread')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc.data(), doc.id))
              .toList();
        });
  }

  static Future<void> editMessage({
    required String receiverId,
    required String messageId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    await _threadRef(receiverId).doc(messageId).update({
      'text': trimmed,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteMessage({
    required String receiverId,
    required String messageId,
  }) async {
    await _threadRef(receiverId).doc(messageId).update({
      'isDeleted': true,
      'text': '',
      'fileUrl': '',
      'fileName': '',
    });
  }

  static Future<void> toggleReaction({
    required String receiverId,
    required String messageId,
    required String emoji,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final docRef = _threadRef(receiverId).doc(messageId);
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final reactions = Map<String, dynamic>.from(
        data['reactions'] as Map<String, dynamic>? ?? {},
      );

      if (reactions[currentUser.uid] == emoji) {
        reactions.remove(currentUser.uid);
      } else {
        reactions[currentUser.uid] = emoji;
      }

      tx.update(docRef, {'reactions': reactions});
    });
  }

  static Future<void> markMessagesAsRead(String otherUserId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final unread = await _threadRef(otherUserId)
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('messageStatus', isNotEqualTo: 'read')
        .get();

    if (unread.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'messageStatus': 'read',
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ======================================================================
  // TYPING INDICATOR
  // ======================================================================

  static Future<void> updateTypingStatus({
    required String receiverId,
    required bool isTyping,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    final chatId = _chatConversationId(currentUser.uid, receiverId);

    await firestore
        .collection('messages')
        .doc(chatId)
        .collection('typing')
        .doc(currentUser.uid)
        .set({'isTyping': isTyping, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Stream<bool> otherUserTypingStream(String otherUserId) {
    final currentUser = auth.currentUser;
    if (currentUser == null) return const Stream<bool>.empty();
    final chatId = _chatConversationId(currentUser.uid, otherUserId);

    return firestore
        .collection('messages')
        .doc(chatId)
        .collection('typing')
        .doc(otherUserId)
        .snapshots()
        .map((snap) {
          final data = snap.data();
          if (data == null) return false;
          final isTyping = data['isTyping'] as bool? ?? false;
          final updatedAt = data['updatedAt'];
          if (isTyping && updatedAt is Timestamp) {
            final age = DateTime.now().difference(updatedAt.toDate());
            if (age.inSeconds > 8) return false;
          }
          return isTyping;
        });
  }

  // ======================================================================
  // ✅ NEW: CHAT LIST STREAM
  // ======================================================================
  //
  // Returns all chats where the current user is a participant.
  // Works for:
  //   - Users they added manually
  //   - Users they messaged
  //   - Users who messaged them

  static Stream<List<ChatSummary>> getMyChatsStream() {
    final currentUser = auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final chats = <ChatSummary>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);

            final otherId = participants.firstWhere(
              (id) => id != currentUser.uid,
              orElse: () => '',
            );
            if (otherId.isEmpty) continue;

            // Fetch the other user's profile
            try {
              final userDoc = await firestore
                  .collection('users')
                  .doc(otherId)
                  .get();
              if (!userDoc.exists) continue;

              final user = ChatUser.fromJson(userDoc.data()!, userDoc.id);
              final lastTime = data['lastMessageTime'];
              final lastMessageTime = lastTime is Timestamp
                  ? lastTime.toDate()
                  : DateTime.now();

              chats.add(
                ChatSummary(
                  user: user,
                  lastMessage: data['lastMessage'] as String? ?? '',
                  lastMessageTime: lastMessageTime,
                  lastSenderId: data['lastSenderId'] as String? ?? '',
                  hasMessages:
                      (data['lastMessage'] as String? ?? '').isNotEmpty,
                ),
              );
            } catch (e) {
              debugPrint('Error loading chat partner $otherId: $e');
            }
          }

          return chats;
        });
  }

  // ======================================================================
  // BLOCKING & REPORTING
  // ======================================================================

  static Future<void> blockUser(String userId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    await firestore.collection('users').doc(currentUser.uid).set({
      'blocked': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  static Future<void> unblockUser(String userId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    await firestore.collection('users').doc(currentUser.uid).set({
      'blocked': FieldValue.arrayRemove([userId]),
    }, SetOptions(merge: true));
  }

  static Stream<List<String>> blockedUserIdsStream() {
    final currentUser = auth.currentUser;
    if (currentUser == null) return const Stream<List<String>>.empty();
    return firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .map(
          (snap) => (snap.data()?['blocked'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
        );
  }

  static Future<bool> hasBlocked({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;
    final doc = await firestore.collection('users').doc(currentUser.uid).get();
    final blocked = doc.data()?['blocked'] as List<dynamic>? ?? const [];
    return blocked.contains(otherUserId);
  }

  static Future<bool> isBlockedBy({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;
    final doc = await firestore.collection('users').doc(otherUserId).get();
    final blocked = doc.data()?['blocked'] as List<dynamic>? ?? const [];
    return blocked.contains(currentUser.uid);
  }

  static Future<void> reportUser({
    required String userId,
    required String reason,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;
    await firestore.collection('reports').add({
      'reportedUserId': userId,
      'reportedBy': currentUser.uid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

// ======================================================================
// CHAT SUMMARY MODEL
// ======================================================================

/// Represents one row in the home screen chat list.
class ChatSummary {
  final ChatUser user;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final bool hasMessages;

  const ChatSummary({
    required this.user,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    this.hasMessages = false,
  });
}

// ======================================================================
// IMAGE HELPER (kept for backward compatibility)
// ======================================================================

class ImageHelper {
  static Future<String> convertToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  static Widget getImageWidget(
    String base64String, {
    double width = 96,
    double height = 96,
  }) {
    if (base64String.isEmpty) return const SizedBox();
    try {
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } catch (e) {
      return const SizedBox();
    }
  }
}
