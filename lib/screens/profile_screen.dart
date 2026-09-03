import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/screens/home_screen.dart';
import 'package:chat_app/screens/login_screen.dart'; // <-- adjust path if different
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  User? _currentUser;
  String _savedName = '';
  String _savedAbout = '';
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentUser = Apis.auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _currentUser;
    if (user == null) return;

    var about = 'Hey! I’m using We Chat';
    try {
      final document = await Apis.firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final data = document.data();
      if (data?['about'] is String &&
          (data?['about'] as String).trim().isNotEmpty) {
        about = data!['about'] as String;
      }
    } catch (error) {
      debugPrint('Unable to load profile: $error');
    }

    if (!mounted) return;
    setState(() {
      _savedName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'User';
      _savedAbout = about;
      _nameController.text = _savedName;
      _aboutController.text = _savedAbout;
    });
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _nameController.text = _savedName;
      _aboutController.text = _savedAbout;
    });
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isEditing = false;
      _nameController.text = _savedName;
      _aboutController.text = _savedAbout;
    });
  }

  Future<void> _saveProfile() async {
    final user = _currentUser;
    final name = _nameController.text.trim();
    final about = _aboutController.text.trim();
    if (user == null) {
      _showSnackBar(
        'Your session has ended. Please sign in again.',
        isError: true,
      );
      return;
    }
    if (name.isEmpty) {
      _showSnackBar('Please add a name before saving.', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      await user.updateDisplayName(name);
      await user.reload();
      await Apis.firestore.collection('users').doc(user.uid).set({
        'name': name,
        'about': about.isEmpty ? 'Hey! I’m using We Chat' : about,
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _currentUser = Apis.auth.currentUser;
        _savedName = name;
        _savedAbout = about.isEmpty ? 'Hey! I’m using We Chat' : about;
        _aboutController.text = _savedAbout;
        _isEditing = false;
      });
      _showSnackBar('Profile saved');
    } catch (error) {
      debugPrint('Unable to save profile: $error');
      _showSnackBar(
        'We could not save your profile. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogout() async {
    // Capture the navigator BEFORE any await, so we don't depend on
    // `context` still being valid/attached to the same tree after
    // the dialog closes and async work runs.
    final navigator = Navigator.of(context, rootNavigator: true);

    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in whenever you want.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorColor,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogOut != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      try {
        await Apis.setUserOnline(false);
      } catch (error) {
        debugPrint('Unable to mark user offline: $error');
      }
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Unable to sign out from Google: $error');
      }
      await Apis.auth.signOut();

      // Navigate straight to the LoginScreen widget instead of relying on
      // a named route ('/login') that may not exist in the route table,
      // and use the captured root navigator so this doesn't get skipped
      // due to a stale/unmounted local context.
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('Unable to log out: $error');
      if (mounted) {
        _showSnackBar('Log out failed. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? AppColors.errorColor
              : AppColors.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) return _buildSignedOutState();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: AppTextStyles.heading2),
        actions: [
          if (_isEditing) ...[
            TextButton(
              onPressed: _isSaving ? null : _cancelEditing,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(width: 4),
          ] else
            IconButton(
              tooltip: 'Edit profile',
              onPressed: _startEditing,
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primaryGreen,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
            child: Column(
              children: [
                _ProfileAvatar(user: _currentUser!, name: _savedName),
                const SizedBox(height: 16),
                Text(
                  _savedName.isEmpty ? 'Your profile' : _savedName,
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.email ?? '',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 28),
                _buildDetailsCard(),
                const SizedBox(height: 24),
                if (!_isEditing)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _handleLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.errorColor,
                        side: const BorderSide(color: AppColors.errorColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log out'),
                    ),
                  ),
              ],
            ),
          ),
          if (_isSaving)
            const LinearProgressIndicator(color: AppColors.primaryGreen),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          _ProfileField(
            icon: Icons.alternate_email_rounded,
            label: 'Email address',
            child: Text(
              _currentUser?.email ?? 'Not available',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.borderColor),
          _ProfileField(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            child: _isEditing
                ? TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 50,
                    decoration: _inputDecoration('What should we call you?'),
                  )
                : Text(_savedName, style: AppTextStyles.bodyMedium),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.borderColor),
          _ProfileField(
            icon: Icons.short_text_rounded,
            label: 'About',
            alignTop: _isEditing,
            child: _isEditing
                ? TextField(
                    controller: _aboutController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 150,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      'Share a short note about yourself',
                    ),
                  )
                : Text(
                    _savedAbout,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.bodySmall,
    isDense: true,
    counterStyle: AppTextStyles.bodySmall,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    filled: true,
    fillColor: AppColors.backgroundColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
    ),
  );

  Widget _buildSignedOutState() => Scaffold(
    appBar: AppBar(title: const Text('Profile', style: AppTextStyles.heading2)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 16),
            Text('You’re signed out', style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            const Text('Sign in to view and edit your profile.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              ),
              child: const Text('Go to sign in'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.icon,
    required this.label,
    required this.child,
    this.alignTop = false,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final bool alignTop;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: alignTop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: alignTop ? 4 : 0),
          child: Icon(icon, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.name});

  final User user;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: AppTextStyles.heading1.copyWith(color: AppColors.primaryGreen),
      ),
    );
    final photoUrl = user.photoURL?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: photoUrl.isEmpty
          ? fallback
          : ClipOval(
              child: SizedBox(
                width: 96,
                height: 96,
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
              ),
            ),
    );
  }
}
