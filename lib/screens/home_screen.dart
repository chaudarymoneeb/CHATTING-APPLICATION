// lib/screens/home_screen.dart

// ignore_for_file: unused_import

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/chatscreen.dart';
import 'package:chat_app/screens/profile_screen.dart';
import 'package:chat_app/screens/user_picker_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _HomeMenuAction { profile, about }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearchResults);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearchResults)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _refreshSearchResults() {
    if (mounted) setState(() {});
  }

  void _openSearch() {
    setState(() => _isSearchVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _isSearchVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const UserPickerScreen()));
        },
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New chat'),
      ),
      body: Column(
        children: [
          if (_isSearchVisible) _buildSearchBar(),
          Expanded(child: _buildChatList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 68,
      leading: const Padding(
        padding: EdgeInsets.only(left: 16),
        child: Icon(
          CupertinoIcons.home,
          color: AppColors.primaryGreen,
          size: 27,
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('We Chat', style: AppTextStyles.heading2),
          SizedBox(height: 2),
          Text('Chats', style: AppTextStyles.bodySmall),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _isSearchVisible ? 'Close search' : 'Search chats',
          onPressed: _isSearchVisible ? _closeSearch : _openSearch,
          icon: Icon(
            _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
            color: AppColors.primaryGreen,
          ),
        ),
        PopupMenuButton<_HomeMenuAction>(
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: AppColors.primaryGreen,
          ),
          onSelected: (action) {
            switch (action) {
              case _HomeMenuAction.profile:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              case _HomeMenuAction.about:
                _showAboutDialog();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _HomeMenuAction.profile,
              child: _MenuItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
              ),
            ),
            PopupMenuItem(
              value: _HomeMenuAction.about,
              child: _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'About We Chat',
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search chats by name or email',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: AppColors.backgroundColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ============ CHAT LIST (NEW) ============
  Widget _buildChatList() {
    return StreamBuilder<List<ChatSummary>>(
      stream: Apis.getMyChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Chat list error: ${snapshot.error}');
          return _buildErrorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        final chats = snapshot.data ?? [];

        final visibleChats = chats
            .where(
              (c) => ChatUserHelper.matches(c.user, _searchController.text),
            )
            .toList();

        if (chats.isEmpty) return _buildEmptyState();
        if (visibleChats.isEmpty) return _buildNoResultsState();

        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
          itemCount: visibleChats.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final chat = visibleChats[index];
            return _ChatTile(
              chat: chat,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(user: chat.user),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() => const _StatusPanel(
    icon: CupertinoIcons.chat_bubble_2,
    title: 'No chats yet',
    message: 'Tap "New chat" to add someone and start a conversation.',
  );

  Widget _buildNoResultsState() => _StatusPanel(
    icon: CupertinoIcons.search,
    title: 'No matches found',
    message: 'Try another name or email address.',
    actionLabel: 'Clear search',
    onAction: _searchController.clear,
  );

  Widget _buildErrorState() => const _StatusPanel(
    icon: CupertinoIcons.wifi_exclamationmark,
    title: 'Unable to load chats',
    message: 'Check your connection and try again.',
  );

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'We Chat',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        CupertinoIcons.chat_bubble_2_fill,
        color: AppColors.primaryGreen,
        size: 36,
      ),
      children: const [
        Text('A thoughtful, simple place to keep in touch with your people.'),
      ],
    );
  }
}

// ======================================================================
// CHAT TILE WIDGET
// ======================================================================

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});

  final ChatSummary chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = ChatUserHelper.displayName(chat.user);
    final me = Apis.auth.currentUser?.uid;
    final isMine = chat.lastSenderId == me;
    final hasMessage = chat.lastMessage.isNotEmpty;

    final subtitle = hasMessage
        ? '${isMine ? "You: " : ""}${chat.lastMessage}'
        : chat.user.about.trim().isEmpty
        ? 'Tap to start chatting'
        : chat.user.about;

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
              _OnlineAvatar(
                imageUrl: chat.user.image,
                initials: ChatUserHelper.initials(chat.user),
                isOnline: chat.user.isOnline,
                radius: 28,
              ),
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
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 13,
                        fontStyle: hasMessage
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasMessage ? _shortTime(chat.lastMessageTime) : '',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.day}/${t.month}';
  }
}

// ======================================================================
// ONLINE AVATAR (inline mini version)
// ======================================================================

class _OnlineAvatar extends StatelessWidget {
  const _OnlineAvatar({
    required this.imageUrl,
    required this.initials,
    required this.isOnline,
    required this.radius,
  });

  final String imageUrl;
  final String initials;
  final bool isOnline;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.5,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryGreen,
        ),
      ),
    );

    return SizedBox(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: imageUrl.trim().isEmpty
                  ? fallback
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => fallback,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : fallback,
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.successColor : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// HELPER WIDGETS
// ======================================================================

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
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
            child: Icon(icon, size: 48, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: AppTextStyles.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
