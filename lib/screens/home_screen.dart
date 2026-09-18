// lib/screens/home_screen.dart

// ignore_for_file: unused_import

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/archived_screen.dart';
import 'package:chat_app/screens/chatscreen.dart';
import 'package:chat_app/screens/new_group_screen.dart';
import 'package:chat_app/screens/profile_screen.dart';
import 'package:chat_app/screens/settings_screen.dart';
import 'package:chat_app/screens/starred_screen.dart';
import 'package:chat_app/screens/user_picker_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _HomeMenuAction { profile, newGroup, starred, archived, settings, about }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchVisible = false;

  // Selection mode
  final Set<String> _selectedChatIds = <String>{};
  bool get _isSelectionMode => _selectedChatIds.isNotEmpty;

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

  void _toggleSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  void _exitSelection() {
    setState(() => _selectedChatIds.clear());
  }

  // ========== SELECTION ACTIONS ==========

  Future<void> _muteSelected(List<ChatSummary> chats, bool mute) async {
    final targets = chats
        .where((c) => _selectedChatIds.contains(c.user.id))
        .toList();
    if (targets.isEmpty) return;
    _exitSelection();

    if (mute) {
      final duration = await _showMuteDurationSheet();
      if (duration == null) return; // cancelled
      for (final c in targets) {
        await Apis.muteChat(otherUserId: c.user.id, duration: duration);
      }
      if (!mounted) return;
      _snack('Chat muted');
    } else {
      for (final c in targets) {
        await Apis.unmuteChat(otherUserId: c.user.id);
      }
      if (!mounted) return;
      _snack('Chat unmuted');
    }
  }

  Future<void> _archiveSelected(List<ChatSummary> chats) async {
    final targets = chats
        .where((c) => _selectedChatIds.contains(c.user.id))
        .toList();
    if (targets.isEmpty) return;
    _exitSelection();

    for (final c in targets) {
      await Apis.archiveChat(otherUserId: c.user.id);
    }
    if (!mounted) return;
    _snack('${targets.length} chat(s) archived');
  }

  /// Returns null if user cancels; Duration.zero = "Always"; other = timed.
  Future<Duration?> _showMuteDurationSheet() async {
    return showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Mute notifications?', style: AppTextStyles.heading3),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'You will not receive notifications for this chat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.access_time_rounded),
              title: const Text('For 8 hours'),
              onTap: () => Navigator.pop(ctx, const Duration(hours: 8)),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_rounded),
              title: const Text('For 1 week'),
              onTap: () => Navigator.pop(ctx, const Duration(days: 7)),
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_rounded),
              title: const Text('Always'),
              onTap: () => Navigator.pop(ctx, Duration.zero),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildAppBar(),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserPickerScreen()),
                );
              },
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add contact'),
            ),
      body: Column(
        children: [
          if (_isSearchVisible && !_isSelectionMode) _buildSearchBar(),
          Expanded(child: _buildChatList()),
        ],
      ),
    );
  }

  // ========== NORMAL APP BAR ==========
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
              case _HomeMenuAction.newGroup:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewGroupScreen()),
                );
              case _HomeMenuAction.starred:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StarredScreen()),
                );
              case _HomeMenuAction.archived:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ArchivedScreen()),
                );
              case _HomeMenuAction.settings:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
              value: _HomeMenuAction.newGroup,
              child: _MenuItem(
                icon: Icons.group_add_outlined,
                label: 'New group',
              ),
            ),
            PopupMenuItem(
              value: _HomeMenuAction.starred,
              child: _MenuItem(
                icon: Icons.star_outline_rounded,
                label: 'Starred',
              ),
            ),
            PopupMenuItem(
              value: _HomeMenuAction.archived,
              child: _MenuItem(icon: Icons.archive_outlined, label: 'Archived'),
            ),
            PopupMenuItem(
              value: _HomeMenuAction.settings,
              child: _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
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

  // ========== SELECTION APP BAR ==========
  PreferredSizeWidget _buildSelectionAppBar() {
    final chats = _lastLoadedChats;
    final selected = chats
        .where((c) => _selectedChatIds.contains(c.user.id))
        .toList();

    // Are ALL selected chats already muted?
    final allMuted = selected.isNotEmpty && selected.every((c) => c.isMuted);

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: _exitSelection,
      ),
      title: Text(
        '${_selectedChatIds.length} selected',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppColors.primaryGreen,
      actions: [
        IconButton(
          tooltip: allMuted ? 'Unmute' : 'Mute',
          icon: Icon(
            allMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: Colors.white,
          ),
          onPressed: () => _muteSelected(chats, !allMuted),
        ),
        IconButton(
          tooltip: 'Archive',
          icon: const Icon(Icons.archive_outlined, color: Colors.white),
          onPressed: () => _archiveSelected(chats),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (action) async {
            switch (action) {
              case 'markRead':
                _snack('Marked as read');
                _exitSelection();
                break;
              case 'markUnread':
                _snack('Marked as unread');
                _exitSelection();
                break;
              case 'selectAll':
                setState(() {
                  for (final c in chats) {
                    _selectedChatIds.add(c.user.id);
                  }
                });
                break;
              case 'clear':
                _snack('Chat cleared');
                _exitSelection();
                break;
              case 'delete':
                _snack('Deleted');
                _exitSelection();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'markRead',
              child: _MenuItem(
                icon: Icons.done_all_rounded,
                label: 'Mark as read',
              ),
            ),
            PopupMenuItem(
              value: 'markUnread',
              child: _MenuItem(
                icon: Icons.mark_chat_unread_outlined,
                label: 'Mark as unread',
              ),
            ),
            PopupMenuItem(
              value: 'selectAll',
              child: _MenuItem(
                icon: Icons.select_all_rounded,
                label: 'Select all',
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: _MenuItem(
                icon: Icons.cleaning_services_outlined,
                label: 'Clear chat',
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: _MenuItem(
                icon: Icons.delete_outline_rounded,
                label: 'Delete chat',
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

  // Cache last loaded chats so selection toolbar can read mute state
  List<ChatSummary> _lastLoadedChats = const [];

  // ============ CHAT LIST ============
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
        _lastLoadedChats = chats;

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
            final selected = _selectedChatIds.contains(chat.user.id);
            return _ChatTile(
              chat: chat,
              isSelected: selected,
              isSelectionMode: _isSelectionMode,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(chat.user.id);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(user: chat.user),
                    ),
                  );
                }
              },
              onLongPress: () {
                _toggleSelection(chat.user.id);
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
    message: 'Tap "Add contact" to add someone and start a conversation.',
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
// CHAT TILE
// ======================================================================

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  final ChatSummary chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

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

    final bg = isSelected
        ? AppColors.primaryGreen.withValues(alpha: 0.12)
        : AppColors.cardBackground;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : Colors.grey.shade400,
                  size: 22,
                ),
                const SizedBox(width: 10),
              ],
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
                          Icon(
                            Icons.volume_off_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ],
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
// ONLINE AVATAR
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
// HELPERS
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
