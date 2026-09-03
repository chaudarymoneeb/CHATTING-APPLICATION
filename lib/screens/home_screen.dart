import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/profile_screen.dart';
import 'package:chat_app/widgets/chat_user_card.dart';
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
        onPressed: () => _showComingSoon('Adding a new contact'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New chat'),
      ),
      body: Column(
        children: [
          if (_isSearchVisible) _buildSearchBar(),
          Expanded(child: _buildUserStream()),
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
          Text('People', style: AppTextStyles.bodySmall),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _isSearchVisible ? 'Close search' : 'Search people',
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
          hintText: 'Search by name or email',
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

  Widget _buildUserStream() {
    return StreamBuilder(
      stream: Apis.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorState();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        final documents = snapshot.data?.docs ?? [];
        final currentUserId = Apis.auth.currentUser?.uid;
        final users = documents
            .map((document) => ChatUser.fromJson(document.data(), document.id))
            .where((user) => user.id != currentUserId)
            .toList();
        final visibleUsers = users
            .where(
              (user) => ChatUserHelper.matches(user, _searchController.text),
            )
            .toList();

        if (users.isEmpty) return _buildEmptyState();
        if (visibleUsers.isEmpty) return _buildNoResultsState();

        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
          itemCount: visibleUsers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => ChatUserCard(
            user: visibleUsers[index],
            onTap: () => _showComingSoon('Private messaging'),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() => _StatusPanel(
    icon: CupertinoIcons.person_2_fill,
    title: 'No one else is here yet',
    message: 'Invite a friend and your conversations will appear here.',
  );

  Widget _buildNoResultsState() => _StatusPanel(
    icon: CupertinoIcons.search,
    title: 'No matches found',
    message: 'Try another name or email address.',
    actionLabel: 'Clear search',
    onAction: _searchController.clear,
  );

  Widget _buildErrorState() => _StatusPanel(
    icon: CupertinoIcons.wifi_exclamationmark,
    title: 'Unable to load people',
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature will be available soon.'),
          behavior: SnackBarBehavior.floating,
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
