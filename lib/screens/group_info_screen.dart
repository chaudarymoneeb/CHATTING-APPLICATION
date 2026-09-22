// lib/screens/group_info_screen.dart

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/models/group_model.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/group_add_member_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _addMembers() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupAddMembersScreen(groupId: widget.groupId),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      await Apis.addGroupMembers(groupId: widget.groupId, userIds: result);
      if (!mounted) return;
      _snack('${result.length} member(s) added');
    }
  }

  Future<void> _removeMember(String uid, String name) async {
    final ok = await _confirm(
      'Remove $name?',
      'They will no longer be in this group.',
      confirmLabel: 'Remove',
    );
    if (ok != true) return;
    await Apis.removeGroupMember(groupId: widget.groupId, userId: uid);
    if (!mounted) return;
    _snack('$name removed');
  }

  Future<void> _makeAdmin(String uid, String name) async {
    final ok = await _confirm(
      'Make $name admin?',
      'Admins can add members and change group info.',
      confirmLabel: 'Make admin',
    );
    if (ok != true) return;
    await Apis.makeAdmin(groupId: widget.groupId, userId: uid);
    if (!mounted) return;
    _snack('$name is now admin');
  }

  Future<void> _dismissAdmin(String uid, String name) async {
    final ok = await _confirm(
      'Dismiss $name as admin?',
      'They will remain in the group as a regular member.',
      confirmLabel: 'Dismiss',
    );
    if (ok != true) return;
    await Apis.dismissAdmin(groupId: widget.groupId, userId: uid);
    if (!mounted) return;
    _snack('$name is no longer admin');
  }

  Future<void> _leaveGroup() async {
    final ok = await _confirm(
      'Leave group?',
      'You will stop receiving messages from this group.',
      confirmLabel: 'Leave',
    );
    if (ok != true) return;
    final success = await Apis.leaveGroup(widget.groupId);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _snack('Failed to leave group', isError: true);
    }
  }

  Future<void> _renameGroup(String current) async {
    final ctrl = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change group name'),
        content: TextField(
          controller: ctrl,
          maxLength: 50,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await Apis.updateGroupName(groupId: widget.groupId, name: newName);
    if (!mounted) return;
    _snack('Group renamed');
  }

  Future<bool?> _confirm(
    String title,
    String message, {
    String confirmLabel = 'OK',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
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
    return StreamBuilder<GroupModel?>(
      stream: Apis.getGroupStream(widget.groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          );
        }
        final group = snapshot.data;
        if (group == null) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundColor,
            body: Center(child: Text('Group not found')),
          );
        }

        final isCreator = group.createdBy == _myUid;
        final iAmAdmin = group.isAdmin(_myUid);
        final canRename = isCreator || iAmAdmin;

        final memberIds = [...group.members];
        memberIds.sort((a, b) {
          int rank(String uid) {
            if (uid == group.createdBy) return 0;
            if (group.admins.contains(uid)) return 1;
            return 2;
          }

          return rank(a).compareTo(rank(b));
        });

        final adminCount = group.admins.length;
        final memberCount = group.members.length - adminCount;

        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  group.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (canRename) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _renameGroup(group.name),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 20,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Group · ${group.members.length} members',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.shield_rounded,
                          value: '$adminCount',
                          label: 'Admins',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people_alt_rounded,
                          value: '$memberCount',
                          label: 'Members',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Material(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _addMembers,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Add members',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                  child: Text(
                    '${group.members.length} MEMBERS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final uid = memberIds[i];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      i == memberIds.length - 1 ? 16 : 6,
                    ),
                    child: _MemberTile(
                      uid: uid,
                      group: group,
                      myUid: _myUid,
                      isCreator: isCreator,
                      onRemove: (name) => _removeMember(uid, name),
                      onMakeAdmin: (name) => _makeAdmin(uid, name),
                      onDismissAdmin: (name) => _dismissAdmin(uid, name),
                    ),
                  );
                }, childCount: memberIds.length),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Material(
                    color: AppColors.errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _leaveGroup,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.exit_to_app_rounded,
                                color: AppColors.errorColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Exit group',
                                style: TextStyle(
                                  color: AppColors.errorColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String uid;
  final GroupModel group;
  final String myUid;
  final bool isCreator;
  final void Function(String name) onRemove;
  final void Function(String name) onMakeAdmin;
  final void Function(String name) onDismissAdmin;

  const _MemberTile({
    required this.uid,
    required this.group,
    required this.myUid,
    required this.isCreator,
    required this.onRemove,
    required this.onMakeAdmin,
    required this.onDismissAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatUser?>(
      stream: Apis.getUserStream(uid),
      builder: (context, snap) {
        final user = snap.data;
        final name = user != null
            ? ChatUserHelper.displayName(user)
            : 'Loading...';
        final isAdmin = group.admins.contains(uid);
        final isMe = uid == myUid;
        final isGroupCreator = group.createdBy == uid;
        final canAct = isCreator && !isMe && !isGroupCreator;

        return Material(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (user?.image.trim().isEmpty ?? true)
                        ? AppColors.primaryGradient
                        : null,
                    image: (user?.image.trim().isNotEmpty ?? false)
                        ? DecorationImage(
                            image: NetworkImage(user!.image),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: (user?.image.trim().isEmpty ?? true)
                      ? Text(
                          user != null ? ChatUserHelper.initials(user) : '?',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isMe ? 'You' : name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isGroupCreator) ...[
                            const SizedBox(width: 6),
                            const _Badge(
                              text: 'Creator',
                              color: Color(0xFF00A884),
                            ),
                          ] else if (isAdmin) ...[
                            const SizedBox(width: 6),
                            const _Badge(
                              text: 'Admin',
                              color: Color(0xFF2196F3),
                            ),
                          ],
                        ],
                      ),
                      if (user != null && user.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canAct)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      if (value == 'remove') {
                        onRemove(name);
                      } else if (value == 'make_admin') {
                        onMakeAdmin(name);
                      } else if (value == 'dismiss_admin') {
                        onDismissAdmin(name);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!isAdmin)
                        const PopupMenuItem(
                          value: 'make_admin',
                          child: Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text('Make group admin'),
                            ],
                          ),
                        ),
                      if (isAdmin)
                        const PopupMenuItem(
                          value: 'dismiss_admin',
                          child: Row(
                            children: [
                              Icon(Icons.remove_moderator_outlined, size: 20),
                              SizedBox(width: 10),
                              Text('Dismiss as admin'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_remove_outlined,
                              size: 20,
                              color: AppColors.errorColor,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Remove from group',
                              style: TextStyle(color: AppColors.errorColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}
