// lib/services/call_log_service.dart

import 'dart:async';

import 'package:chat_app/api/api.dart';
import 'package:chat_app/models/call_log_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

/// Tracks active call state and saves a log when a call ends.
class CallLogService {
  CallLogService._();
  static final CallLogService instance = CallLogService._();

  /// Currently active call info (per session)
  _ActiveCall? _active;

  /// Called when outgoing call button is pressed
  void onCallInitiated({
    required String receiverId,
    required String receiverName,
    required bool isVideo,
  }) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    _active = _ActiveCall(
      startedAt: DateTime.now(),
      callerId: me.uid,
      callerName: me.displayName ?? 'You',
      receiverId: receiverId,
      receiverName: receiverName,
      isVideo: isVideo,
      wasAnswered: false,
      isIncoming: false,
    );
    debugPrint('📞 Call initiated to $receiverName');
  }

  /// Called when incoming call arrives (from ZEGOCLOUD)
  void onCallReceived({
    required String callerId,
    required String callerName,
    required bool isVideo,
  }) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    _active = _ActiveCall(
      startedAt: DateTime.now(),
      callerId: callerId,
      callerName: callerName,
      receiverId: me.uid,
      receiverName: me.displayName ?? 'You',
      isVideo: isVideo,
      wasAnswered: false,
      isIncoming: true,
    );
    debugPrint('📞 Incoming call from $callerName');
  }

  /// Called when call is answered
  void onCallAnswered() {
    _active?.wasAnswered = true;
    _active?.answeredAt = DateTime.now();
    debugPrint('✅ Call answered');
  }

  /// Called when call ends.
  /// [endReason] can be 'cancel' (caller hung up before answer),
  /// 'decline' (receiver rejected), 'hangup' (normal), 'timeout'.
  Future<void> onCallEnded({String endReason = 'hangup'}) async {
    final active = _active;
    if (active == null) return;
    _active = null;

    final now = DateTime.now();
    int duration = 0;
    String status;

    if (!active.wasAnswered) {
      // Never connected
      if (active.isIncoming) {
        status = endReason == 'decline' ? 'rejected' : 'missed';
      } else {
        status = endReason == 'decline' ? 'rejected' : 'cancelled';
      }
    } else {
      // Answered normally
      final answeredAt = active.answeredAt ?? active.startedAt;
      duration = now.difference(answeredAt).inSeconds;
      status = active.isIncoming ? 'incoming' : 'outgoing';
    }

    await Apis.saveCallLog(
      callerId: active.callerId,
      callerName: active.callerName,
      receiverId: active.receiverId,
      receiverName: active.receiverName,
      type: active.isVideo ? 'video' : 'audio',
      status: status,
      durationSeconds: duration,
    );

    debugPrint('📞 Call ended: $status, ${duration}s');
  }

  void reset() {
    _active = null;
  }
}

class _ActiveCall {
  final DateTime startedAt;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final bool isVideo;
  final bool isIncoming;
  bool wasAnswered;
  DateTime? answeredAt;

  _ActiveCall({
    required this.startedAt,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.isVideo,
    required this.isIncoming,
    this.wasAnswered = false,
  });
}
