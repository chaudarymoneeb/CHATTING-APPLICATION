// lib/api/api.dart

// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:io';

import 'package:chat_app/models/call_log_model.dart';
import 'package:chat_app/models/group_model.dart';
import 'package:chat_app/models/message_model.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/services/notification_trigger.dart';
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

  static Stream<ChatUser?> getUserStream(String uid) {
    return firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists ? ChatUser.fromJson(d.data()!, d.id) : null);
  }

  // ======================================================================
  // CHAT ID HELPERS
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
  // ADD USER
  // ======================================================================

  static Future<bool> addUserToChats({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    try {
      final ref = _chatDocRef(otherUserId);
      final snap = await ref.get();

      if (snap.exists) return true;

      await ref.set({
        'chatId': _chatConversationId(currentUser.uid, otherUserId),
        'participants': [currentUser.uid, otherUserId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'addedBy': [currentUser.uid],
        'mutedBy': <String>[],
        'muteExpiry': <String, dynamic>{},
        'archivedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User added to chat list: $otherUserId');
      return true;
    } catch (e) {
      debugPrint('❌ addUserToChats error: $e');
      return false;
    }
  }

  static Future<void> removeChatFromList({required String otherUserId}) async {
    try {
      await _chatDocRef(otherUserId).delete();
    } catch (e) {
      debugPrint('removeChatFromList error: $e');
    }
  }

  // ======================================================================
  // MESSAGES
  // ======================================================================

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

    await _threadRef(receiverId).doc(message.id).set(message.toFirestore());

    final preview = isAttachment ? _previewFor(fileType) : cleanText;
    await _upsertChatSummary(
      otherUserId: receiverId,
      lastMessage: preview,
      lastMessageTime: now,
      lastSenderId: currentUser.uid,
    );

    // 🔔 FCM TRIGGER
    try {
      final senderDoc = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final senderName = (senderDoc.data()?['name'] ?? 'User').toString();

      NotificationTrigger.notifyNewMessage(
        chatId: _chatConversationId(currentUser.uid, receiverId),
        messageId: message.id,
        senderId: currentUser.uid,
        receiverId: receiverId,
        senderName: senderName,
        text: cleanText,
        fileType: fileType,
      );
    } catch (e) {
      debugPrint('❌ FCM trigger error: $e');
    }

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

  static Future<void> markMessagesAsDelivered(String otherUserId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final pending = await _threadRef(otherUserId)
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('messageStatus', isEqualTo: 'sent')
        .get();
    if (pending.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in pending.docs) {
      batch.update(doc.reference, {'messageStatus': 'delivered'});
    }
    await batch.commit();
  }

  // ======================================================================
  // TYPING
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
  // MUTE / ARCHIVE
  // ======================================================================

  static Future<bool> muteChat({
    required String otherUserId,
    Duration? duration,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    try {
      final ref = _chatDocRef(otherUserId);
      final expiryMs = duration == null
          ? 0
          : DateTime.now().add(duration).millisecondsSinceEpoch;

      await ref.set({
        'mutedBy': FieldValue.arrayUnion([currentUser.uid]),
        'muteExpiry': {currentUser.uid: expiryMs},
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('muteChat error: $e');
      return false;
    }
  }

  static Future<bool> unmuteChat({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    try {
      final ref = _chatDocRef(otherUserId);
      await ref.set({
        'mutedBy': FieldValue.arrayRemove([currentUser.uid]),
        'muteExpiry': {currentUser.uid: FieldValue.delete()},
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('unmuteChat error: $e');
      return false;
    }
  }

  static Future<bool> archiveChat({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    try {
      await _chatDocRef(otherUserId).set({
        'archivedBy': FieldValue.arrayUnion([currentUser.uid]),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('archiveChat error: $e');
      return false;
    }
  }

  static Future<bool> unarchiveChat({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    try {
      await _chatDocRef(otherUserId).set({
        'archivedBy': FieldValue.arrayRemove([currentUser.uid]),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('unarchiveChat error: $e');
      return false;
    }
  }

  static Future<bool> isChatMuted({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;
    final snap = await _chatDocRef(otherUserId).get();
    if (!snap.exists) return false;
    return _computeMuted(snap.data(), currentUser.uid);
  }

  static Future<bool> isChatArchived({required String otherUserId}) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;
    final snap = await _chatDocRef(otherUserId).get();
    if (!snap.exists) return false;
    final archived = List<String>.from(snap.data()?['archivedBy'] ?? []);
    return archived.contains(currentUser.uid);
  }

  static bool _computeMuted(Map<String, dynamic>? data, String uid) {
    if (data == null) return false;
    final mutedBy = List<String>.from(data['mutedBy'] ?? const []);
    if (!mutedBy.contains(uid)) return false;

    final expiryMap = Map<String, dynamic>.from(
      data['muteExpiry'] as Map? ?? const {},
    );
    final raw = expiryMap[uid];
    if (raw == null) return true;

    int ms = 0;
    if (raw is int) ms = raw;
    if (raw is Timestamp) ms = raw.millisecondsSinceEpoch;

    if (ms == 0) return true;
    return DateTime.fromMillisecondsSinceEpoch(ms).isAfter(DateTime.now());
  }

  // ======================================================================
  // CHAT LISTS
  // ======================================================================

  static Stream<List<ChatSummary>> getMyChatsStream() =>
      _chatsStream(archived: false);

  static Stream<List<ChatSummary>> getArchivedChatsStream() =>
      _chatsStream(archived: true);

  static Stream<List<ChatSummary>> _chatsStream({required bool archived}) {
    final currentUser = auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final results = <ChatSummary>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final otherId = participants.firstWhere(
              (id) => id != currentUser.uid,
              orElse: () => '',
            );
            if (otherId.isEmpty) continue;

            final archivedBy = List<String>.from(
              data['archivedBy'] ?? const [],
            );
            final isArchived = archivedBy.contains(currentUser.uid);
            if (isArchived != archived) continue;

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

              results.add(
                ChatSummary(
                  user: user,
                  lastMessage: data['lastMessage'] as String? ?? '',
                  lastMessageTime: lastMessageTime,
                  lastSenderId: data['lastSenderId'] as String? ?? '',
                  hasMessages:
                      (data['lastMessage'] as String? ?? '').isNotEmpty,
                  isMuted: _computeMuted(data, currentUser.uid),
                  isArchived: isArchived,
                ),
              );
            } catch (e) {
              debugPrint('Error loading chat partner $otherId: $e');
            }
          }

          return results;
        });
  }

  // ======================================================================
  // BLOCKING
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

  static Stream<List<ChatUser>> blockedUsersStream() {
    final currentUser = auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .asyncMap((snap) async {
          final blockedIds =
              (snap.data()?['blocked'] as List<dynamic>? ?? const [])
                  .map((e) => e.toString())
                  .toList();

          if (blockedIds.isEmpty) return <ChatUser>[];

          final users = <ChatUser>[];
          for (final id in blockedIds) {
            try {
              final doc = await firestore.collection('users').doc(id).get();
              if (doc.exists) {
                users.add(ChatUser.fromJson(doc.data()!, doc.id));
              }
            } catch (e) {
              debugPrint('Error loading blocked user $id: $e');
            }
          }
          return users;
        });
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

  // ======================================================================
  // 🆕 GROUPS
  // ======================================================================

  static CollectionReference<Map<String, dynamic>> get _groups =>
      firestore.collection('groups');

  static Future<String?> createGroup({
    required String name,
    required List<String> memberIds,
    String image = '',
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return null;

    try {
      final members = <String>{currentUser.uid, ...memberIds}.toList();
      final ref = await _groups.add({
        'name': name.trim(),
        'image': image,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'members': members,
        'admins': [currentUser.uid],
        'lastMessage': '',
        'lastSenderId': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      try {
        NotificationTrigger.notifyGroupCreated(
          groupId: ref.id,
          groupName: name.trim(),
          createdBy: currentUser.uid,
          members: members,
        );
      } catch (e) {
        debugPrint('❌ FCM group trigger error: $e');
      }

      return ref.id;
    } catch (e) {
      debugPrint('createGroup error: $e');
      return null;
    }
  }

  static Stream<List<GroupModel>> getMyGroupsStream() {
    final currentUser = auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _groups
        .where('members', arrayContains: currentUser.uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(GroupModel.fromDoc).toList();
          list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return list;
        });
  }

  static Stream<GroupModel?> getGroupStream(String groupId) {
    return _groups
        .doc(groupId)
        .snapshots()
        .map((d) => d.exists ? GroupModel.fromDoc(d) : null);
  }

  static Future<bool> sendGroupMessage({
    required String groupId,
    required String text,
    String fileType = 'text',
    String fileUrl = '',
    String fileName = '',
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    try {
      final userDoc = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final senderName = (userDoc.data()?['name'] ?? 'User').toString();

      await _groups.doc(groupId).collection('messages').add({
        'senderId': currentUser.uid,
        'senderName': senderName,
        'text': text,
        'fileType': fileType,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'messageStatus': 'sent',
        'isDeleted': false,
      });

      final preview = fileType == 'text'
          ? text
          : fileType == 'image'
          ? '📷 Photo'
          : fileType == 'audio'
          ? '🎤 Voice message'
          : fileType == 'document'
          ? '📎 Document'
          : text;

      await _groups.doc(groupId).update({
        'lastMessage': preview,
        'lastSenderId': currentUser.uid,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      try {
        NotificationTrigger.notifyNewGroupMessage(
          groupId: groupId,
          senderId: currentUser.uid,
          senderName: senderName,
          text: text,
          fileType: fileType,
        );
      } catch (e) {
        debugPrint('❌ FCM group trigger error: $e');
      }

      return true;
    } catch (e) {
      debugPrint('sendGroupMessage error: $e');
      return false;
    }
  }

  static Stream<List<Message>> getGroupMessagesStream(String groupId) {
    return _groups
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return Message(
              id: d.id,
              senderId: (data['senderId'] ?? '').toString(),
              receiverId: groupId,
              text: (data['text'] ?? '').toString(),
              fileType: (data['fileType'] ?? 'text').toString(),
              fileUrl: (data['fileUrl'] ?? '').toString(),
              fileName: (data['fileName'] ?? '').toString(),
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              messageStatus: (data['messageStatus'] ?? 'sent').toString(),
              isDeleted: data['isDeleted'] == true,
            );
          }).toList(),
        );
  }

  static Future<bool> addGroupMembers({
    required String groupId,
    required List<String> userIds,
  }) async {
    try {
      await _groups.doc(groupId).update({
        'members': FieldValue.arrayUnion(userIds),
      });
      return true;
    } catch (e) {
      debugPrint('addGroupMembers error: $e');
      return false;
    }
  }

  static Future<bool> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _groups.doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
        'admins': FieldValue.arrayRemove([userId]),
      });
      return true;
    } catch (e) {
      debugPrint('removeGroupMember error: $e');
      return false;
    }
  }

  static Future<bool> leaveGroup(String groupId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;
    return removeGroupMember(groupId: groupId, userId: currentUser.uid);
  }

  static Future<bool> makeAdmin({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _groups.doc(groupId).update({
        'admins': FieldValue.arrayUnion([userId]),
      });
      return true;
    } catch (e) {
      debugPrint('makeAdmin error: $e');
      return false;
    }
  }

  static Future<bool> dismissAdmin({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _groups.doc(groupId).update({
        'admins': FieldValue.arrayRemove([userId]),
      });
      return true;
    } catch (e) {
      debugPrint('dismissAdmin error: $e');
      return false;
    }
  }

  static Future<bool> updateGroupName({
    required String groupId,
    required String name,
  }) async {
    try {
      await _groups.doc(groupId).update({'name': name.trim()});
      return true;
    } catch (e) {
      debugPrint('updateGroupName error: $e');
      return false;
    }
  }

  // ======================================================================
  // 📞 CALL LOGS
  // ======================================================================

  static CollectionReference<Map<String, dynamic>> get _callLogs =>
      firestore.collection('call_logs');

  static Future<String?> saveCallLog({
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
    required String type,
    required String status,
    int durationSeconds = 0,
    bool isGroup = false,
    String? groupId,
  }) async {
    try {
      final ref = await _callLogs.add({
        'callerId': callerId,
        'callerName': callerName,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'type': type,
        'status': status,
        'durationSeconds': durationSeconds,
        'timestamp': FieldValue.serverTimestamp(),
        'isGroup': isGroup,
        'groupId': groupId,
        'participants': [callerId, receiverId],
      });
      debugPrint('✅ Call log saved: $status ($type)');
      return ref.id;
    } catch (e) {
      debugPrint('❌ saveCallLog error: $e');
      return null;
    }
  }

  static Stream<List<CallLogModel>> getMyCallLogsStream() {
    final currentUser = auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _callLogs
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map(CallLogModel.fromDoc).toList());
  }

  static Future<bool> deleteCallLog(String logId) async {
    try {
      await _callLogs.doc(logId).delete();
      return true;
    } catch (e) {
      debugPrint('❌ deleteCallLog error: $e');
      return false;
    }
  }

  static Future<bool> clearMyCallLogs() async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;
    try {
      final snap = await _callLogs
          .where('participants', arrayContains: currentUser.uid)
          .get();
      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('❌ clearMyCallLogs error: $e');
      return false;
    }
  }
}

// ======================================================================
// CHAT SUMMARY
// ======================================================================

class ChatSummary {
  final ChatUser user;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final bool hasMessages;
  final bool isMuted;
  final bool isArchived;

  const ChatSummary({
    required this.user,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    this.hasMessages = false,
    this.isMuted = false,
    this.isArchived = false,
  });
}

// ======================================================================
// IMAGE HELPER
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
