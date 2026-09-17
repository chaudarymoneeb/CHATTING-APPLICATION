// lib/models/usermodel.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUser {
  final String id;
  final String name;
  final String email;
  final String image;
  final String about;
  final bool isOnline;

  /// ISO-8601 string (kept as String for compatibility with existing
  /// screens that call DateTime.parse(user.lastActive)).
  final String lastActive;
  final String pushToken;
  final String createdAt;

  /// User IDs that this user has blocked.
  final List<String> blockedUsers;

  const ChatUser({
    required this.id,
    required this.name,
    required this.email,
    required this.image,
    required this.about,
    required this.isOnline,
    required this.lastActive,
    required this.pushToken,
    required this.createdAt,
    this.blockedUsers = const [],
  });

  bool hasBlocked(String userId) => blockedUsers.contains(userId);

  ChatUser copyWith({
    String? name,
    String? about,
    String? image,
    bool? isOnline,
    List<String>? blockedUsers,
  }) {
    return ChatUser(
      id: id,
      name: name ?? this.name,
      email: email,
      image: image ?? this.image,
      about: about ?? this.about,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive,
      pushToken: pushToken,
      createdAt: createdAt,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }

  factory ChatUser.fromJson(Map<String, dynamic> json, String id) {
    return ChatUser(
      id: id,
      name: json['name'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      image: json['image'] as String? ?? '',
      about: json['about'] as String? ?? "Hey! I'm using We Chat",
      isOnline: json['is_online'] as bool? ?? false,
      lastActive: _readTimeField(json['last_active']),
      pushToken: json['push_token'] as String? ?? '',
      createdAt: _readTimeField(json['created_at']),
      blockedUsers: (json['blocked'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static String _readTimeField(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is String && value.isNotEmpty) return value;
    return DateTime.now().toIso8601String();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'image': image,
    'about': about,
    'is_online': isOnline,
    'push_token': pushToken,
  };
}
