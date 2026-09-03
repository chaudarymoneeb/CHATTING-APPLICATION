import 'package:chat_app/models/usermodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}
