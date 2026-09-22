// lib/services/notification_service.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/chatscreen.dart';
import 'package:chat_app/screens/group_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background handler (top-level function — @pragma zaroori)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message: ${message.messageId}');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final messageId = message.data['messageId']?.toString();
  if (messageId != null && messageId.isNotEmpty) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collectionGroup('thread')
          .where('id', isEqualTo: messageId)
          .where('receiverId', isEqualTo: user.uid)
          .get()
          .then((snapshot) async {
            for (final doc in snapshot.docs) {
              await doc.reference.update({'messageStatus': 'delivered'});
            }
          });
    }
  }

  final notifications = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for chat messages and calls',
    importance: Importance.high,
    playSound: true,
  );
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  final notification = message.notification;
  final title = notification?.title ?? message.data['title']?.toString();
  final body = notification?.body ?? message.data['body']?.toString();
  if (title == null && body == null) return;

  await notifications.show(
    id: message.hashCode,
    title: title ?? 'New message',
    body: body ?? 'You received a new message',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'Used for chat messages and calls',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Global navigator key — notification tap pe navigate karne ke liye
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Android channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for chat messages and calls',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification_sound'),
  );

  Future<void> initialize() async {
    // 1. Permissions maango
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('🔔 Permission status: ${settings.authorizationStatus}');

    // 2. Local notifications init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('👆 Notification tapped: ${response.payload}');
        _handleNotificationTap(response.payload);
      },
    );

    // 3. Channel create karo (Android 8+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // 4. Background handler register
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. iOS foreground presentation
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 6. FCM token get + save
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint('🔔 FCM Token: $token');
      await _saveTokenToFirestore(token);
    }

    // 7. Token refresh listener
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
    FirebaseAuth.instance.authStateChanges().listen((_) {
      syncTokenForCurrentUser();
    });

    // 8. Foreground message listener
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('🔔 Foreground message: ${message.messageId}');
      _showLocalNotification(message);
    });

    // 9. Background tap listener
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('👆 Tapped (bg): ${message.data}');
      _handleMessageData(message.data);
    });

    // 10. Terminated state se tap
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      debugPrint('👆 Tapped (terminated): ${initial.data}');
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleMessageData(initial.data);
      });
    }
  }

  Future<void> syncTokenForCurrentUser() async {
    final token = await _fcm.getToken();
    if (token != null) await _saveTokenToFirestore(token);
  }

  // Save token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ No user logged in — token not saved');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'push_token': token,
      }, SetOptions(merge: true));
      debugPrint('✅ Token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Token save error: $e');
    }
  }

  // Show local notification (foreground me)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    await _localNotifications.show(
      id: message.hashCode,
      title: title ?? 'New message',
      body: body ?? 'You received a new message',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: _channel.sound,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // Handle notification tap (from local notification)
  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _handleMessageData(data);
    } catch (e) {
      debugPrint('❌ Tap parse error: $e');
    }
  }

  // Actual navigation logic
  Future<void> _handleMessageData(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? data['action']?.toString() ?? '';
    debugPrint('🎯 Navigate for type: $type');

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (type == 'newGroupMessage' || type == 'groupCreated') {
      final groupId = data['groupId']?.toString();
      if (groupId?.isNotEmpty == true) {
        navigator.push(
          MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groupId!)),
        );
        return;
      }
    }

    final isChatNotification =
        type.isEmpty ||
        type == 'chat' ||
        type == 'message' ||
        type == 'newMessage';
    if (!isChatNotification) {
      navigator.pushNamed('/home');
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final senderId = data['senderId']?.toString();
    final receiverId = data['receiverId']?.toString();
    final otherUserId = senderId == currentUserId ? receiverId : senderId;
    if (otherUserId == null || otherUserId.isEmpty) {
      navigator.pushNamed('/home');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUserId)
        .get();
    if (!userDoc.exists || userDoc.data() == null) {
      navigator.pushNamed('/home');
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(user: ChatUser.fromJson(userDoc.data()!, userDoc.id)),
      ),
    );
  }

  // Logout pe token delete
  Future<void> deleteToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'push_token': '',
      }, SetOptions(merge: true));
    }
    await _fcm.deleteToken();
  }
}
