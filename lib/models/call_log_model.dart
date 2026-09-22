// lib/models/call_log_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { audio, video }

enum CallStatus { missed, outgoing, incoming, rejected, cancelled }

class CallLogModel {
  final String id;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallType type;
  final CallStatus status;
  final int durationSeconds;
  final DateTime timestamp;
  final bool isGroup;
  final String? groupId;

  CallLogModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.type,
    required this.status,
    required this.durationSeconds,
    required this.timestamp,
    this.isGroup = false,
    this.groupId,
  });

  factory CallLogModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CallLogModel(
      id: doc.id,
      callerId: (data['callerId'] ?? '').toString(),
      callerName: (data['callerName'] ?? 'User').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      receiverName: (data['receiverName'] ?? 'User').toString(),
      type: (data['type'] ?? 'audio').toString() == 'video'
          ? CallType.video
          : CallType.audio,
      status: _parseStatus(data['status']?.toString()),
      durationSeconds: (data['durationSeconds'] ?? 0) as int,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isGroup: data['isGroup'] == true,
      groupId: data['groupId']?.toString(),
    );
  }

  static CallStatus _parseStatus(String? s) {
    switch (s) {
      case 'missed':
        return CallStatus.missed;
      case 'outgoing':
        return CallStatus.outgoing;
      case 'incoming':
        return CallStatus.incoming;
      case 'rejected':
        return CallStatus.rejected;
      case 'cancelled':
        return CallStatus.cancelled;
      default:
        return CallStatus.outgoing;
    }
  }

  String get statusString {
    switch (status) {
      case CallStatus.missed:
        return 'missed';
      case CallStatus.outgoing:
        return 'outgoing';
      case CallStatus.incoming:
        return 'incoming';
      case CallStatus.rejected:
        return 'rejected';
      case CallStatus.cancelled:
        return 'cancelled';
    }
  }

  String get typeString => type == CallType.video ? 'video' : 'audio';

  /// Formatted duration like "02:34"
  String get durationFormatted {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
