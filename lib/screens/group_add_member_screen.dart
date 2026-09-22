// lib/screens/group_add_members_screen.dart

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/group_model.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/widgets/gradient_appbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupAddMembersScreen extends StatefulWidget {
  final String groupId;
  const GroupAddMembersScreen({super.key, required this.groupId});

  @override
  State<GroupAddMembersScreen> createState() => _GroupAddMembersScreenState();
}

class _GroupAddMembersScreenState extends State<GroupAddMembersScreen> {
  final Set<String> _selected = <String>{};
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _done() {
    if (_selected.isEmpty) return;
    Navigator.pop(context, _selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroupModel?>(
      stream: Apis.getGroupStream(widget.groupId),
      builder: (context, groupSnap) {
        final existing = groupSnap.data?.members ?? const <String>[];

        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          appBar: GradientAppBar(
            title: 'Add members',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _done,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Add ${_selected.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search contacts',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _selected.map((id) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(
                              id.length > 8 ? '${id.substring(0, 6)}…' : id,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () =>
                                setState(() => _selected.remove(id)),
                            backgroundColor: AppColors.primaryGreen.withValues(
                              alpha: 0.12,
                            ),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(
                child: StreamBuilder(
                  stream: Apis.getAllUsers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      );
                    }
                    final me = FirebaseAuth.instance.currentUser?.uid;
                    final query = _search.text.trim();
                    final users = snapshot.data!.docs
                        .map((d) => ChatUser.fromJson(d.data(), d.id))
                        .where(
                          (u) =>
                              u.id != me &&
                              !existing.contains(u.id) &&
                              ChatUserHelper.matches(u, query),
                        )
                        .toList();

                    if (users.isEmpty) {
                      return const _EmptyUsersState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final user = users[i];
                        final sel = _selected.contains(user.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() {
                                  if (sel) {
                                    _selected.remove(user.id);
                                  } else {
                                    _selected.add(user.id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: user.image.trim().isEmpty
                                            ? AppColors.primaryGradient
                                            : null,
                                        image: user.image.trim().isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(user.image),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: user.image.trim().isEmpty
                                          ? Text(
                                              ChatUserHelper.initials(user),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ChatUserHelper.displayName(user),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (user.email.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              user.email,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: sel
                                            ? AppColors.primaryGradient
                                            : null,
                                        color: sel ? null : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: sel
                                              ? Colors.transparent
                                              : AppColors.textSecondary
                                                    .withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: sel
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyUsersState extends StatelessWidget {
  const _EmptyUsersState();

  @override
  Widget build(BuildContext context) {
    return Center(
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
                Icons.person_search_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No contacts to add',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All your contacts are already in this group.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
