// ignore_for_file: unnecessary_underscores, unused_local_variable

import 'dart:io';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/screens/home_screen.dart';
import 'package:chat_app/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  String _savedName = '';
  String _savedAbout = '';
  String _profileImageBase64 = ''; // Base64 encoded image
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = Apis.auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _currentUser;
    if (user == null) return;

    var about = 'Hey! I\'m using We Chat';
    var photoBase64 = '';

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

      // Get base64 image from Firestore if available
      if (data?['profileImage'] is String &&
          (data?['profileImage'] as String).isNotEmpty) {
        photoBase64 = data!['profileImage'] as String;
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
      _profileImageBase64 = photoBase64;
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

      // Update Firestore with name, about, and base64 image
      await Apis.firestore.collection('users').doc(user.uid).set({
        'name': name,
        'about': about.isEmpty ? 'Hey! I\'m using We Chat' : about,
        'profileImage': _profileImageBase64, // Save base64 image
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _currentUser = Apis.auth.currentUser;
        _savedName = name;
        _savedAbout = about.isEmpty ? 'Hey! I\'m using We Chat' : about;
        _aboutController.text = _savedAbout;
        _isEditing = false;
      });
      _showSnackBar('Profile saved successfully! ✨');
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

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 60, // Lower quality to reduce base64 size
        maxWidth: 500, // Resize to reduce base64 size
        maxHeight: 500,
      );

      if (pickedFile == null) return; // User cancelled

      setState(() => _isUploading = true);

      // Convert image to base64
      final base64Image = await _convertImageToBase64(File(pickedFile.path));

      // Save base64 to Firestore
      await _saveImageToFirestore(base64Image);

      if (!mounted) return;
      setState(() {
        _profileImageBase64 = base64Image;
      });

      _showSnackBar('Profile picture updated successfully! ✨');
    } catch (error) {
      debugPrint('Failed to update photo: $error');
      if (mounted) {
        _showSnackBar(
          'Failed to update photo. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting image to base64: $e');
      throw Exception('Failed to convert image');
    }
  }

  Future<void> _saveImageToFirestore(String base64Image) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not signed in');

    try {
      // Update Firestore with base64 image
      await Apis.firestore.collection('users').doc(user.uid).set({
        'profileImage': base64Image,
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Base64 image saved to Firestore successfully');
    } catch (e) {
      debugPrint('Error saving image to Firestore: $e');
      throw Exception('Failed to save image: $e');
    }
  }

  Future<void> _handleLogout() async {
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

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Change Profile Picture',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose an option to update your profile photo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              // Two Images in a Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Camera Option
                  _buildBottomSheetImageOption(
                    imagePath: 'assets/icons/camera.png',
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadImage(ImageSource.camera);
                    },
                  ),
                  // Gallery Option
                  _buildBottomSheetImageOption(
                    imagePath: 'assets/icons/image-upload.png',
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetImageOption({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imagePath,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            child: Column(
              children: [
                // Profile Avatar with Edit Icon Overlay at Bottom-Right
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _ProfileAvatar(
                      user: _currentUser!,
                      name: _savedName,
                      imageBase64: _profileImageBase64,
                    ),
                    // Edit Icon at bottom-right
                    Container(
                      margin: const EdgeInsets.only(right: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryGreen,
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: _showBottomSheet,
                                tooltip: 'Change profile picture',
                              ),
                      ),
                    ),
                  ],
                ),
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
                    child: FilledButton.icon(
                      onPressed: _startEditing,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.update_rounded),
                      label: const Text(
                        'Update Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_isEditing)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You are in edit mode. Tap Save to update or Cancel to discard changes.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_isSaving || _isUploading)
            const LinearProgressIndicator(color: AppColors.primaryGreen),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleLogout,
        backgroundColor: AppColors.errorColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Logout'),
        tooltip: 'Sign out of your account',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            Text('You\'re signed out', style: AppTextStyles.heading3),
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
  const _ProfileAvatar({
    required this.user,
    required this.name,
    required this.imageBase64,
  });

  final User user;
  final String name;
  final String imageBase64;

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

    // Try to decode base64 image if available
    if (imageBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(imageBase64);
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: SizedBox(
              width: 96,
              height: 96,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
      }
    }

    // Fallback to Firebase Auth photoURL
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
                  placeholder: (_, __) => fallback,
                  errorWidget: (_, __, ___) => fallback,
                ),
              ),
            ),
    );
  }
}
