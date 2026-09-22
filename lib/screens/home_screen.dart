// lib/screens/home_screen.dart

// ignore_for_file: unused_import

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/group_model.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/archived_screen.dart';
import 'package:chat_app/screens/call_logs_screen.dart'; // 📞 NEW
import 'package:chat_app/screens/chatscreen.dart';
import 'package:chat_app/screens/group_chat_screen.dart';
import 'package:chat_app/screens/new_group_screen.dart';
import 'package:chat_app/screens/profile_screen.dart';
import 'package:chat_app/screens/settings_screen.dart';
import 'package:chat_app/screens/starred_screen.dart';
import 'package:chat_app/screens/user_picker_screen.dart';
import 'package:chat_app/widgets/gradient_appbar.dart';
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

  Future<void> _muteSelected(List<ChatSummary> chats, bool mute) async {
    final targets = chats
        .where((c) => _selectedChatIds.contains(c.user.id))
        .toList();
    if (targets.isEmpty) return;
    _exitSelection();
    if (mute) {
      final duration = await _showMuteDurationSheet();
      if (duration == null) return;
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

  Future<Duration?> _showMuteDurationSheet() async {
    return showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildAppBar(),
      floatingActionButton: _isSelectionMode
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UserPickerScreen()),
                  );
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text(
                  'Add contact',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.softGradient),
        child: Column(
          children: [
            if (_isSearchVisible && !_isSelectionMode) _buildSearchBar(),
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return GradientAppBar(
      toolbarHeight: 68,
      leading: const Padding(
        padding: EdgeInsets.only(left: 16),
        child: Icon(CupertinoIcons.home, color: Colors.white, size: 26),
      ),
      titleWidget: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'We Chat',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 2),
          Text('Chats', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
      actions: [
        // 📞 CALLS ICON — NEW
        IconButton(
          tooltip: 'Calls',
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CallLogsScreen()));
          },
          icon: const Icon(Icons.call_rounded, color: Colors.white),
        ),

        // 🔍 Search
        IconButton(
          tooltip: _isSearchVisible ? 'Close search' : 'Search chats',
          onPressed: _isSearchVisible ? _closeSearch : _openSearch,
          icon: Icon(
            _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
            color: Colors.white,
          ),
        ),

        // ⋮ Menu
        PopupMenuButton<_HomeMenuAction>(
          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (action) {
            switch (action) {
              case _HomeMenuAction.profile:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                break;
              case _HomeMenuAction.newGroup:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewGroupScreen()),
                );
                break;
              case _HomeMenuAction.starred:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StarredScreen()),
                );
                break;
              case _HomeMenuAction.archived:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ArchivedScreen()),
                );
                break;
              case _HomeMenuAction.settings:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                break;
              case _HomeMenuAction.about:
                _showAboutDialog();
                break;
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

  PreferredSizeWidget _buildSelectionAppBar() {
    final chats = _lastLoadedChats;
    final selected = chats
        .where((c) => _selectedChatIds.contains(c.user.id))
        .toList();
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
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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

  List<ChatSummary> _lastLoadedChats = const [];

  Widget _buildChatList() {
    return StreamBuilder<List<ChatSummary>>(
      stream: Apis.getMyChatsStream(),
      builder: (context, chatSnap) {
        return StreamBuilder<List<GroupModel>>(
          stream: Apis.getMyGroupsStream(),
          builder: (context, groupSnap) {
            if (chatSnap.hasError || groupSnap.hasError) {
              return _buildErrorState();
            }
            final chatsLoading =
                chatSnap.connectionState == ConnectionState.waiting &&
                !chatSnap.hasData;
            final groupsLoading =
                groupSnap.connectionState == ConnectionState.waiting &&
                !groupSnap.hasData;
            if (chatsLoading && groupsLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              );
            }
            final chats = chatSnap.data ?? [];
            final groups = groupSnap.data ?? [];
            _lastLoadedChats = chats;
            final query = _searchController.text.trim().toLowerCase();

            final visibleChats = chats.where((c) {
              if (query.isEmpty) return true;
              return ChatUserHelper.matches(c.user, query) ||
                  c.lastMessage.toLowerCase().contains(query);
            }).toList();

            final visibleGroups = groups.where((g) {
              if (query.isEmpty) return true;
              return g.name.toLowerCase().contains(query) ||
                  g.lastMessage.toLowerCase().contains(query);
            }).toList();

            if (visibleChats.isEmpty && visibleGroups.isEmpty) {
              if (chats.isEmpty && groups.isEmpty) return _buildEmptyState();
              return _buildNoResultsState();
            }

            final items = <_ListItem>[
              ...visibleGroups.map((g) => _ListItem.group(g)),
              ...visibleChats.map((c) => _ListItem.chat(c)),
            ];

            return ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                if (item.group != null) {
                  final group = item.group!;
                  return _GroupTile(
                    group: group,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupChatScreen(groupId: group.id),
                        ),
                      );
                    },
                  );
                }
                final chat = item.chat!;
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
                  onLongPress: () => _toggleSelection(chat.user.id),
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

class _ListItem {
  final ChatSummary? chat;
  final GroupModel? group;
  const _ListItem._({this.chat, this.group});
  factory _ListItem.chat(ChatSummary c) => _ListItem._(chat: c);
  factory _ListItem.group(GroupModel g) => _ListItem._(group: g);
}

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;
  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasMessage = group.lastMessage.isNotEmpty;
    final me = Apis.auth.currentUser?.uid;
    final isMine = group.lastSenderId == me;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isMine && hasMessage)
                            const Text(
                              'You: ',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              hasMessage
                                  ? group.lastMessage
                                  : 'Tap to start chatting',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontStyle: hasMessage
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hasMessage ? _shortTime(group.lastMessageTime) : '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textLight,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.10)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: AppColors.primaryGreen, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          if (chat.isMuted) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.volume_off_rounded,
                              size: 15,
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
                          color: AppColors.textSecondary,
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
                    color: AppColors.textLight,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
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
      width: radius * 2 + 8,
      height: radius * 2 + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: radius * 2 + 8,
            height: radius * 2 + 8,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isOnline
                  ? AppColors.primaryGradient
                  : const LinearGradient(colors: [Colors.grey, Colors.grey]),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
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
            ),
          ),
          if (isOnline)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.successColor,
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

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.textSecondary),
      const SizedBox(width: 12),
      Text(label),
    ],
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
            child: Icon(icon, size: 48, color: Colors.white),
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
