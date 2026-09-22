// lib/screens/new_group_screen.dart

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/group_chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final Set<String> _selectedUserIds = <String>{};
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      _snack('Please enter a group name', isError: true);
      return;
    }
    if (_selectedUserIds.isEmpty) {
      _snack('Select at least 1 member', isError: true);
      return;
    }

    setState(() => _isCreating = true);
    final groupId = await Apis.createGroup(
      name: name,
      memberIds: _selectedUserIds.toList(),
    );
    if (!mounted) return;
    setState(() => _isCreating = false);

    if (groupId == null) {
      _snack('Failed to create group', isError: true);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groupId)),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError
              ? AppColors.errorColor
              : AppColors.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New group', style: AppTextStyles.heading2),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _createGroup,
              icon: const Icon(
                Icons.check_rounded,
                color: AppColors.primaryGreen,
                size: 26,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _groupNameController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'Group name',
                prefixIcon: const Icon(
                  Icons.group_outlined,
                  color: AppColors.primaryGreen,
                ),
                filled: true,
                fillColor: AppColors.backgroundColor,
                counterText: '',
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
          if (_selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _selectedUserIds.map((id) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '✓ $id',
                          style: const TextStyle(fontSize: 11),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () =>
                            setState(() => _selectedUserIds.remove(id)),
                        backgroundColor: AppColors.primaryGreen.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.backgroundColor,
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
          const SizedBox(height: 8),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: Apis.getAllUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }
        final me = FirebaseAuth.instance.currentUser?.uid;
        final query = _searchController.text.trim();
        final users = snapshot.data!.docs
            .map((d) => ChatUser.fromJson(d.data(), d.id))
            .where((u) => u.id != me)
            .where((u) => ChatUserHelper.matches(u, query))
            .toList();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final user = users[i];
            final selected = _selectedUserIds.contains(user.id);
            return Material(
              color: selected
                  ? AppColors.primaryGreen.withValues(alpha: 0.12)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedUserIds.remove(user.id);
                    } else {
                      _selectedUserIds.add(user.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? AppColors.primaryGreen
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryGreen.withValues(
                          alpha: 0.12,
                        ),
                        backgroundImage: user.image.trim().isNotEmpty
                            ? NetworkImage(user.image)
                            : null,
                        child: user.image.trim().isEmpty
                            ? Text(
                                ChatUserHelper.initials(user),
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ChatUserHelper.displayName(user),
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              user.email,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
