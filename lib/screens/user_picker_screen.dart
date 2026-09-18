// lib/screens/user_picker_screen.dart

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/chatscreen.dart';
import 'package:flutter/material.dart';

class UserPickerScreen extends StatefulWidget {
  const UserPickerScreen({super.key});

  @override
  State<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<UserPickerScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _query => _searchController.text.trim();

  bool get _looksLikeEmail =>
      _query.contains('@') && _query.contains('.') && !_query.contains(' ');

  /// Add user → create chat doc → open ChatScreen
  Future<void> _addAndOpen(ChatUser user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    final ok = await Apis.addUserToChats(otherUserId: user.id);

    if (!mounted) return;
    Navigator.of(context).pop(); // close loader

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add contact'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add contact', style: AppTextStyles.heading2),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Enter email or search by name',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _searchController.clear,
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
          ),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: Apis.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load users'));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        final me = Apis.auth.currentUser?.uid;
        final allUsers = snapshot.data!.docs
            .map((d) => ChatUser.fromJson(d.data(), d.id))
            .where((u) => u.id != me)
            .toList();

        // 1) If the user typed something that looks like an email, check
        //    for an EXACT email match first.
        if (_looksLikeEmail) {
          ChatUser? exact;
          for (final u in allUsers) {
            if (u.email.toLowerCase() == _query.toLowerCase()) {
              exact = u;
              break;
            }
          }

          if (exact == null) return _buildNoEmailState();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'MATCH FOUND',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              _PickerTile(user: exact, onTap: () => _addAndOpen(exact!)),
            ],
          );
        }

        // 2) Otherwise, generic name/email substring filter
        final matches = allUsers
            .where((u) => ChatUserHelper.matches(u, _query))
            .toList();

        if (matches.isEmpty) return _buildNoResultsState();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: matches.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final user = matches[i];
            return _PickerTile(user: user, onTap: () => _addAndOpen(user));
          },
        );
      },
    );
  }

  Widget _buildNoEmailState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_off_rounded,
              size: 48,
              color: AppColors.errorColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No account with this email',
            style: AppTextStyles.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No user registered with "$_query". Ask them to sign up first.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildNoResultsState() => Center(
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
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No matches found',
            style: AppTextStyles.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try typing a full email address.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ======================================================================
// PICKER TILE
// ======================================================================

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.user, required this.onTap});

  final ChatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = ChatUserHelper.displayName(user);
    final initials = ChatUserHelper.initials(user);

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
              _Avatar(
                imageUrl: user.image,
                initials: initials,
                isOnline: user.isOnline,
                radius: 26,
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
                    const SizedBox(height: 2),
                    Text(
                      user.email.isNotEmpty
                          ? user.email
                          : (user.about.trim().isEmpty
                                ? 'Available'
                                : user.about),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// AVATAR
// ======================================================================

class _Avatar extends StatelessWidget {
  const _Avatar({
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
