// lib/screens/archived_screen.dart

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/screens/chatscreen.dart';
import 'package:chat_app/widgets/online_avatar.dart';
import 'package:flutter/material.dart';

class ArchivedScreen extends StatelessWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived', style: AppTextStyles.heading2),
      ),
      body: StreamBuilder<List<ChatSummary>>(
        stream: Apis.getArchivedChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load archived chats'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          final chats = snapshot.data ?? [];
          if (chats.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: chats.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final chat = chats[i];
              return _ArchivedTile(
                chat: chat,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(user: chat.user),
                    ),
                  );
                },
                onUnarchive: () => _unarchive(context, chat),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unarchive(BuildContext context, ChatSummary chat) async {
    await Apis.unarchiveChat(otherUserId: chat.user.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${ChatUserHelper.displayName(chat.user)} unarchived'),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 2),
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
              color: AppColors.primaryGreen.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.archive_outlined,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No archived chats',
            style: AppTextStyles.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Chats you archive will appear here. Long-press a chat on the home screen to archive it.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ArchivedTile extends StatelessWidget {
  const _ArchivedTile({
    required this.chat,
    required this.onTap,
    required this.onUnarchive,
  });

  final ChatSummary chat;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    final name = ChatUserHelper.displayName(chat.user);
    final hasMessage = chat.lastMessage.isNotEmpty;

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              OnlineAvatar(
                imageUrl: chat.user.image,
                initials: ChatUserHelper.initials(chat.user),
                isOnline: chat.user.isOnline,
                radius: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (chat.isMuted) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.volume_off_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasMessage ? chat.lastMessage : chat.user.about,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Unarchive',
                onPressed: onUnarchive,
                icon: const Icon(
                  Icons.unarchive_outlined,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
