class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  String messageStatus;
  bool isSynced;

  // ✅ NEW — attachment fields
  final String? fileUrl; // Firebase Storage download URL
  final String? fileType; // 'image' | 'document' | null

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.messageStatus = 'pending',
    this.isSynced = false,
    this.fileUrl,
    this.fileType,
  });

  /// For SQLite (local DB) — stores isSynced as int
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'messageStatus': messageStatus,
      'isSynced': isSynced ? 1 : 0,
      // ✅ NEW
      'fileUrl': fileUrl,
      'fileType': fileType,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      text: map['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      messageStatus: map['messageStatus'] as String? ?? 'pending',
      isSynced: (map['isSynced'] as int?) == 1,
      // ✅ NEW
      fileUrl: map['fileUrl'] as String?,
      fileType: map['fileType'] as String?,
    );
  }

  /// For Firestore — timestamp as DateTime
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'messageStatus': messageStatus,
      // ✅ NEW
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileType != null) 'fileType': fileType,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      text: json['text'] as String,
      timestamp: json['timestamp'] is DateTime
          ? json['timestamp'] as DateTime
          : DateTime.now(),
      messageStatus: json['messageStatus'] as String? ?? 'pending',
      isSynced: true,
      // ✅ NEW
      fileUrl: json['fileUrl'] as String?,
      fileType: json['fileType'] as String?,
    );
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    String? messageStatus,
    bool? isSynced,
    // ✅ NEW
    String? fileUrl,
    String? fileType,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      messageStatus: messageStatus ?? this.messageStatus,
      isSynced: isSynced ?? this.isSynced,
      // ✅ NEW
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
    );
  }

  bool isFromCurrentUser(String currentUserId) => senderId == currentUserId;

  bool isDelivered() => messageStatus == 'delivered' || messageStatus == 'read';

  // ✅ Helper: is this an attachment?
  bool get isImage => fileType == 'image' && (fileUrl?.isNotEmpty ?? false);
  bool get isDocument =>
      fileType == 'document' && (fileUrl?.isNotEmpty ?? false);
  bool get isText => fileType == null || fileType == 'text';

  String getFormattedTime() {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  String toString() =>
      'Message(id: $id, from: $senderId, text: $text, '
      'type: $fileType, status: $messageStatus)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
