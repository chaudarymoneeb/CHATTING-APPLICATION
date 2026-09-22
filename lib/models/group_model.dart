// lib/models/group_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String image;
  final String createdBy;
  final List<String> members;
  final List<String> admins;
  final String lastMessage;
  final String lastSenderId;
  final DateTime lastMessageTime;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.image,
    required this.createdBy,
    required this.members,
    required this.admins,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageTime,
    required this.createdAt,
  });

  bool isAdmin(String uid) => admins.contains(uid);

  factory GroupModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GroupModel(
      id: doc.id,
      name: (data['name'] ?? 'Group').toString(),
      image: (data['image'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      members: List<String>.from(data['members'] ?? const []),
      admins: List<String>.from(data['admins'] ?? const []),
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastSenderId: (data['lastSenderId'] ?? '').toString(),
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
