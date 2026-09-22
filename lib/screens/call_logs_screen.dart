// lib/screens/call_logs_screen.dart

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/models/call_log_model.dart';
import 'package:chat_app/widgets/gradient_appbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CallLogsScreen extends StatelessWidget {
  const CallLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GradientAppBar(
        title: 'Calls',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              if (value == 'clear') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('Clear call logs?'),
                    content: const Text('All call history will be removed.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.errorColor,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await Apis.clearMyCallLogs();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Call logs cleared'),
                        backgroundColor: AppColors.successColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Clear call logs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.softGradient),
        child: StreamBuilder<List<CallLogModel>>(
          stream: Apis.getMyCallLogsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load call logs'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              );
            }

            final logs = snapshot.data ?? [];
            if (logs.isEmpty) return _buildEmptyState();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                return _CallTile(
                  log: logs[i],
                  onDelete: () => Apis.deleteCallLog(logs[i].id),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.call_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No call history',
            style: AppTextStyles.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your calls will appear here.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _CallTile extends StatelessWidget {
  final CallLogModel log;
  final VoidCallback onDelete;

  const _CallTile({required this.log, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOutgoing = log.callerId == me;
    final isMissed = log.status == CallStatus.missed;
    final isVideo = log.type == CallType.video;

    // Name to show: other person
    final displayName = isOutgoing ? log.receiverName : log.callerName;

    // Icon color
    Color iconColor;
    IconData icon;
    if (isMissed) {
      iconColor = AppColors.errorColor;
      icon = isVideo ? Icons.videocam_off_rounded : Icons.call_missed_rounded;
    } else if (isOutgoing) {
      iconColor = AppColors.successColor;
      icon = isVideo ? Icons.videocam_rounded : Icons.call_made_rounded;
    } else {
      iconColor = AppColors.infoColor;
      icon = isVideo ? Icons.videocam_rounded : Icons.call_received_rounded;
    }

    final subtitle = isMissed
        ? 'Missed ${isVideo ? "video" : "voice"} call'
        : isOutgoing
        ? (isVideo ? 'Outgoing video call' : 'Outgoing voice call')
        : (isVideo ? 'Incoming video call' : 'Incoming voice call');

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO: Navigate to call again (optional)
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isMissed
                            ? AppColors.errorColor
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(icon, size: 14, color: iconColor),
                        const SizedBox(width: 4),
                        Text(
                          subtitle +
                              (log.durationFormatted.isNotEmpty
                                  ? ' · ${log.durationFormatted}'
                                  : ''),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _shortTime(log.timestamp),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11.5,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isVideo)
                    Icon(
                      Icons.videocam_rounded,
                      color: AppColors.primaryGreen,
                      size: 20,
                    )
                  else
                    Icon(
                      Icons.call_rounded,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.day}/${t.month}';
  }
}
