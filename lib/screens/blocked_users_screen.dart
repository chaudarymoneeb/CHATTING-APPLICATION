// lib/screens/blocked_users_screen.dart

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/widgets/online_avatar.dart';
import 'package:flutter/material.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked users', style: AppTextStyles.heading2),
      ),
      body: StreamBuilder<List<ChatUser>>(
        stream: Apis.blockedUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load blocked users'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final user = users[i];
              return _BlockedTile(
                user: user,
                onUnblock: () => _unblock(context, user),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unblock(BuildContext context, ChatUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unblock ${ChatUserHelper.displayName(user)}?'),
        content: const Text(
          'They will be able to message you again and appear in your chat list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await Apis.unblockUser(user.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${ChatUserHelper.displayName(user)} unblocked'),
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
              Icons.block_rounded,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No blocked users',
            style: AppTextStyles.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Users you block will appear here. You can unblock them anytime.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _BlockedTile extends StatelessWidget {
  const _BlockedTile({required this.user, required this.onUnblock});

  final ChatUser user;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            OnlineAvatar(
              imageUrl: user.image,
              initials: ChatUserHelper.initials(user),
              isOnline: false,
              radius: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ChatUserHelper.displayName(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email.isEmpty ? 'No email' : user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onUnblock,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Unblock'),
            ),
          ],
        ),
      ),
    );
  }
}
