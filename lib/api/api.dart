import 'dart:convert';
import 'dart:io';

import 'package:chat_app/models/message_model.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// `Apis` is a utility class — it holds only `static` members, so it is
/// never meant to be instantiated. The private constructor `Apis._()`
/// enforces that: nobody outside this file can even try to write `Apis()`,
/// because the only constructor is private.
class Apis {
  const Apis._();

  /// Holds the currently logged-in user's profile data (from Firestore).
  /// `late` means: "I promise this will be set before anyone reads it."
  /// If something reads `Apis.me` before `getCurrentUserDetails()` has
  /// successfully finished, this will throw a `LateInitializationError`.
  static late ChatUser me;

  // Shared Firebase instances so the rest of the app never has to type
  // `FirebaseAuth.instance` / `FirebaseFirestore.instance` directly.
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Returns true if the currently logged-in user already has a
  /// document in the `users` collection.
  static Future<bool> userExists() async {
    final user = auth.currentUser;
    if (user == null) return false;
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  /// Creates a Firestore document for a new user, or, if one already
  /// exists, just marks them online and bumps `last_active`.
  static Future<void> createUser(User user) async {
    final userDocument = firestore.collection('users').doc(user.uid);

    if ((await userDocument.get()).exists) {
      // Document already exists (e.g. user signed out and back in) —
      // no need to recreate it, just refresh presence info.
      await userDocument.set({
        'is_online': true,
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    // Brand-new user: build a fresh ChatUser with sensible defaults.
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
      'created_at': FieldValue.serverTimestamp(),
      'last_active': FieldValue.serverTimestamp(),
    });
  }

  /// Loads the current user's profile into `me`.
  ///
  /// FIXES APPLIED vs the original version:
  /// 1. Uses `await` directly instead of mixing `.then()` with `await`
  ///    inside a non-async callback (that was a compile error).
  /// 2. Guards against `auth.currentUser` being null, instead of letting
  ///    `.doc(null)` silently create/read a bogus random document.
  /// 3. When the user is brand new (no Firestore doc yet), it now
  ///    creates the doc AND re-fetches it so `me` actually gets set.
  ///    Previously, `me` was left uninitialized in this branch, which
  ///    would crash the app the next time `Apis.me` was read.
  static Future<void> getCurrentUserDetails() async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return; // nothing to load if nobody's signed in

    final snapshot = await firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (snapshot.exists) {
      // Existing user — just parse what's already in Firestore.
      me = ChatUser.fromJson(snapshot.data()!, snapshot.id);
    } else {
      // First-time user — create their document, then re-fetch it so
      // `me` is populated with real (server-confirmed) data rather than
      // being left unset.
      await createUser(currentUser);

      final newSnapshot = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      me = ChatUser.fromJson(newSnapshot.data()!, newSnapshot.id);
    }
  }

  /// Marks the current user online/offline in Firestore.
  static Future<void> setUserOnline(bool isOnline) async {
    final user = auth.currentUser;
    if (user == null) return;

    await firestore.collection('users').doc(user.uid).set({
      'is_online': isOnline,
      'last_active': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Streams every user in the `users` collection except the currently
  /// logged-in one (used for the chat list / contacts screen).
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    return firestore
        .collection('users')
        .where('id', isNotEqualTo: auth.currentUser?.uid)
        .snapshots();
  }

  static String _chatConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Sends a new message to the other user inside a shared conversation room.
  static Future<bool> sendMessage({
    required String receiverId,
    required String messageText,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null || messageText.trim().isEmpty) return false;

    final cleanText = messageText.trim();
    final message = Message(
      id: '${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}',
      senderId: currentUser.uid,
      receiverId: receiverId,
      text: cleanText,
      timestamp: DateTime.now(),
      messageStatus: 'sent',
      isSynced: true,
    );

    final chatId = _chatConversationId(currentUser.uid, receiverId);

    await firestore
        .collection('messages')
        .doc(chatId)
        .collection('thread')
        .doc(message.id)
        .set({
          'id': message.id,
          'senderId': message.senderId,
          'receiverId': message.receiverId,
          'text': message.text,
          'timestamp': Timestamp.fromDate(message.timestamp),
          'messageStatus': message.messageStatus,
          'isSynced': message.isSynced,
        });

    return true;
  }

  /// Streams the ordered messages for the conversation between two users.
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
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final timestamp = data['timestamp'];

            return Message(
              id: data['id'] as String? ?? doc.id,
              senderId: data['senderId'] as String? ?? '',
              receiverId: data['receiverId'] as String? ?? '',
              text: data['text'] as String? ?? '',
              timestamp: timestamp is Timestamp
                  ? timestamp.toDate()
                  : DateTime.now(),
              messageStatus: data['messageStatus'] as String? ?? 'sent',
              isSynced: data['isSynced'] as bool? ?? true,
            );
          }).toList();
        });
  }
}

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
