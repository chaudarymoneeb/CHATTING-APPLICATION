import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/chatscreen.dart';
import 'package:flutter/material.dart';

class ChatUserCard extends StatelessWidget {
  const ChatUserCard({super.key, required this.user});

  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    final name = ChatUserHelper.displayName(user);
    final statusText = user.isOnline ? 'Online' : 'Offline';

    return Semantics(
      button: true,
      label: '$name, $statusText',
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          // ✅ FIXED: Navigation to ChatScreen added
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ChatScreen(user: user)));
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _UserAvatar(user: user),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.about.trim().isEmpty
                            ? 'Hey! I\'m using We Chat'
                            : user.about,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (user.isOnline)
                  const Tooltip(
                    message: 'Online',
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: AppColors.successColor,
                    ),
                  ),
                const SizedBox(width: 8),

                // ✅ TIME INSTEAD OF ARROW
                Text(
                  _formatLastMessageTime(user),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastMessageTime(ChatUser user) {
    try {
      final lastTime = DateTime.parse(user.lastActive);
      final now = DateTime.now();
      final difference = now.difference(lastTime);

      if (difference.inSeconds < 60) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${lastTime.day}/${lastTime.month}';
      }
    } catch (e) {
      return '';
    }
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
      child: Text(
        ChatUserHelper.initials(user),
        style: AppTextStyles.heading3.copyWith(color: AppColors.primaryGreen),
      ),
    );

    if (user.image.trim().isEmpty) return fallback;

    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: CachedNetworkImage(
          imageUrl: user.image,
          fit: BoxFit.cover,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
