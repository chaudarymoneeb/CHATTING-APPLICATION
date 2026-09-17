// lib/models/message_model.dart
//
// Message model, extended to support:
//  - attachments (image / document / audio) via fileType + fileUrl + fileName
//  - reactions (userId -> emoji)
//  - edit history (isEdited / editedAt)
//  - soft delete (isDeleted)
//  - read receipts (readAt)
//
// Kept backwards compatible with the previous shape (id, senderId,
// receiverId, text, timestamp, messageStatus, isSynced) so existing
// sqlite rows / Firestore docs without the new fields still parse fine.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;

  /// pending | sent | delivered | read
  final String messageStatus;
  final bool isSynced;

  /// text | image | document | audio
  final String fileType;
  final String fileUrl;
  final String fileName;

  /// userId -> emoji
  final Map<String, String> reactions;

  final bool isEdited;
  final bool isDeleted;
  final DateTime? editedAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.messageStatus = 'sent',
    this.isSynced = true,
    this.fileType = 'text',
    this.fileUrl = '',
    this.fileName = '',
    this.reactions = const {},
    this.isEdited = false,
    this.isDeleted = false,
    this.editedAt,
    this.readAt,
  });

  bool get hasAttachment => fileType != 'text' && fileUrl.isNotEmpty;

  Message copyWith({
    String? text,
    String? messageStatus,
    bool? isSynced,
    Map<String, String>? reactions,
    bool? isEdited,
    bool? isDeleted,
    DateTime? editedAt,
    DateTime? readAt,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      text: text ?? this.text,
      timestamp: timestamp,
      messageStatus: messageStatus ?? this.messageStatus,
      isSynced: isSynced ?? this.isSynced,
      fileType: fileType,
      fileUrl: fileUrl,
      fileName: fileName,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      editedAt: editedAt ?? this.editedAt,
      readAt: readAt ?? this.readAt,
    );
  }

  // ============ SQLITE (local cache) ============

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      text: map['text'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
      ),
      messageStatus: map['messageStatus'] as String? ?? 'sent',
      isSynced: (map['isSynced'] as int? ?? 1) == 1,
      fileType: map['fileType'] as String? ?? 'text',
      fileUrl: map['fileUrl'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      reactions: _decodeReactions(map['reactions'] as String?),
      isEdited: (map['isEdited'] as int? ?? 0) == 1,
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      editedAt: map['editedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['editedAt'] as int)
          : null,
      readAt: map['readAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['readAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'messageStatus': messageStatus,
      'isSynced': isSynced ? 1 : 0,
      'fileType': fileType,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'reactions': _encodeReactions(reactions),
      'isEdited': isEdited ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
      'editedAt': editedAt?.millisecondsSinceEpoch,
      'readAt': readAt?.millisecondsSinceEpoch,
    };
  }

  // ============ FIRESTORE ============

  factory Message.fromFirestore(Map<String, dynamic> data, String docId) {
    final timestamp = data['timestamp'];
    final editedAt = data['editedAt'];
    final readAt = data['readAt'];

    return Message(
      id: data['id'] as String? ?? docId,
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      messageStatus: data['messageStatus'] as String? ?? 'sent',
      isSynced: data['isSynced'] as bool? ?? true,
      fileType: data['fileType'] as String? ?? 'text',
      fileUrl: data['fileUrl'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      reactions: (data['reactions'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
      isEdited: data['isEdited'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      editedAt: editedAt is Timestamp ? editedAt.toDate() : null,
      readAt: readAt is Timestamp ? readAt.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'messageStatus': messageStatus,
      'isSynced': isSynced,
      'fileType': fileType,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'reactions': reactions,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
    };
  }

  static Map<String, String> _decodeReactions(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  static String _encodeReactions(Map<String, String> reactions) {
    return jsonEncode(reactions);
  }
}
