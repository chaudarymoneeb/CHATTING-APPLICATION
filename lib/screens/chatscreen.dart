// lib/screens/chat_screen.dart

// ignore_for_file: duplicate_import, unnecessary_null_comparison, deprecated_member_use, file_names, avoid_print

import 'dart:async';
import 'dart:io';

import 'package:chat_app/api/api.dart';
import 'package:chat_app/api/cloudinary_cloud/cloudinary.dart';
import 'package:chat_app/api/database_service/database_service.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/chat_user.dart';
import 'package:chat_app/helper/connectivity_helper.dart';
import 'package:chat_app/models/message_model.dart';
import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/screens/full_screen_image.dart'; // 👈 NAYA IMPORT

import 'package:chat_app/widgets/audio_message_bubble.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum _ChatMenuAction {
  viewContact,
  muteToggle,
  archiveToggle,
  clearChat,
  blockUser,
  reportUser,
}

class ChatScreen extends StatefulWidget {
  final ChatUser user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final _db = DatabaseService();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  List<Message> _messages = [];
  bool _isOnline = true;
  String _currentUserId = '';
  bool _isSending = false;
  bool _isUploading = false;
  bool _showEmoji = false;

  // Chat state
  bool _isMuted = false;
  bool _isArchived = false;
  bool _iBlockedThem = false;

  // Voice recording
  bool _isRecording = false;
  DateTime? _recordStartTime;
  Timer? _recordTimer;
  String _recordDuration = '0:00';

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadChatState();
    _loadMessages();
    _setupConnectivityListener();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
  }

  Future<void> _loadChatState() async {
    final muted = await Apis.isChatMuted(otherUserId: widget.user.id);
    final archived = await Apis.isChatArchived(otherUserId: widget.user.id);
    final blocked = await Apis.hasBlocked(otherUserId: widget.user.id);

    if (!mounted) return;
    setState(() {
      _isMuted = muted;
      _isArchived = archived;
      _iBlockedThem = blocked;
    });
  }

  // ============ 👈 NAYA: FULL SCREEN HELPERS ============

  /// Contact ki profile image full screen mein kholo
  void _openContactPhoto() {
    final url = widget.user.image.trim();
    if (url.isEmpty) {
      _showSnackBar('No profile picture', isSuccess: false);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(
          imageUrl: url,
          heroTag: 'chat-avatar-${widget.user.id}',
          senderName: ChatUserHelper.displayName(widget.user),
        ),
      ),
    );
  }

  /// Chat message ki image full screen mein kholo
  void _openChatImage({required String imageUrl, required String heroTag}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(imageUrl: imageUrl, heroTag: heroTag),
      ),
    );
  }

  // ============ EMOJI ============
  void _toggleEmojiPicker() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _showEmoji = true);
      });
    }
  }

  // ============ LOAD MESSAGES ============
  Future<void> _loadMessages() async {
    try {
      final messages = await _db.getMessages(_currentUserId, widget.user.id);
      if (mounted) setState(() => _messages = messages);
      if (_isOnline) _listenToFirebase();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  void _listenToFirebase() {
    _messagesSubscription?.cancel();
    _messagesSubscription =
        Apis.getMessagesStream(
          currentUserId: _currentUserId,
          otherUserId: widget.user.id,
        ).listen((firebaseMessages) {
          if (mounted) {
            setState(() => _messages = firebaseMessages);
            _scrollToBottom();
          }
        }, onError: (error) => debugPrint('Error: $error'));
  }

  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = ConnectivityHelper.onConnectivityChanged()
        .listen((isOnline) {
          if (mounted) {
            setState(() => _isOnline = isOnline);
            if (isOnline) {
              _showSnackBar('🟢 Back online! Syncing...', isSuccess: true);
              _loadMessages();
            } else {
              _showSnackBar('🔴 You\'re offline.', isSuccess: false);
            }
          }
        }, onError: (error) => debugPrint('Connectivity error: $error'));
  }

  // ============ SEND TEXT ============
  Future<void> _sendMessage() async {
    if (_iBlockedThem) {
      _showSnackBar('You blocked this user', isSuccess: false);
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    try {
      final success = await Apis.sendMessage(
        receiverId: widget.user.id,
        messageText: text,
      );

      if (success) {
        _messageController.clear();
        if (_showEmoji) setState(() => _showEmoji = false);
        _scrollToBottom();
      } else {
        _showSnackBar('❌ Failed to send', isSuccess: false);
      }
    } catch (e) {
      _showSnackBar('❌ Error: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ============ UPLOAD ============
  Future<void> _uploadAndSendFile({
    required File file,
    required String type,
    String? fileName,
  }) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final resourceType = type == 'audio' ? 'video' : 'auto';

      final url = await CloudinaryService.uploadFile(
        file,
        resourceType: resourceType,
        fileName: fileName,
      );

      if (url == null || url.isEmpty) {
        _showSnackBar('☁️ Upload failed. Please try again.', isSuccess: false);
        return;
      }

      final success = await Apis.sendMessage(
        receiverId: widget.user.id,
        messageText: '',
        fileType: type,
        fileUrl: url,
        fileName: fileName ?? file.path.split('/').last,
      );

      if (success) {
        _scrollToBottom();
        _showSnackBar('✅ Sent', isSuccess: true);
      } else {
        _showSnackBar('❌ Failed to send attachment', isSuccess: false);
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      _showSnackBar('❌ Upload failed: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ============ PICKERS ============
  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      await _uploadAndSendFile(
        file: File(picked.path),
        type: 'image',
        fileName: picked.name,
      );
    } catch (e) {
      _showSnackBar('❌ Gallery error: $e', isSuccess: false);
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (picked == null) return;
      await _uploadAndSendFile(
        file: File(picked.path),
        type: 'image',
        fileName: picked.name,
      );
    } catch (e) {
      _showSnackBar('❌ Camera error: $e', isSuccess: false);
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.isEmpty) return;

      final file = result.first;
      final path = file.path;
      if (path == null) return;

      await _uploadAndSendFile(
        file: File(path),
        type: 'document',
        fileName: file.name,
      );
    } catch (e) {
      debugPrint('Document picker error: $e');
      _showSnackBar('❌ Document error: $e', isSuccess: false);
    }
  }

  // ============ VOICE RECORDING ============
  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        _showSnackBar('🎤 Microphone permission denied', isSuccess: false);
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(const RecordConfig(), path: path);

      setState(() {
        _isRecording = true;
        _recordStartTime = DateTime.now();
        _recordDuration = '0:00';
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _recordStartTime == null) return;
        final elapsed = DateTime.now().difference(_recordStartTime!);
        final m = elapsed.inMinutes;
        final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        setState(() => _recordDuration = '$m:$s');
      });
    } catch (e) {
      debugPrint('Record start error: $e');
      _showSnackBar('❌ Recording failed: $e', isSuccess: false);
    }
  }

  Future<void> _stopAndSendRecording({bool cancel = false}) async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _recordStartTime = null;
        _recordDuration = '0:00';
      });

      if (cancel || path == null) {
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
        return;
      }

      final file = File(path);
      if (!await file.exists()) return;

      await _uploadAndSendFile(
        file: file,
        type: 'audio',
        fileName: path.split('/').last,
      );
    } catch (e) {
      debugPrint('Record stop error: $e');
      _showSnackBar('❌ Recording failed: $e', isSuccess: false);
    }
  }

  // ============ BOTTOM SHEET ============
  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickFromGallery();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickFromCamera();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.description,
                  label: 'Document',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickDocument();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  // ============ APP BAR (UPDATED — tappable + Hero) ============
  PreferredSizeWidget _buildAppBar() {
    final avatarUrl = widget.user.image.trim();
    final hasAvatar = avatarUrl.isNotEmpty;

    return AppBar(
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: hasAvatar ? _openContactPhoto : null,
        child: Row(
          children: [
            Hero(
              tag: 'chat-avatar-${widget.user.id}',
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                backgroundImage: hasAvatar
                    ? CachedNetworkImageProvider(
                        CloudinaryService.thumbnailUrl(avatarUrl),
                      )
                    : null,
                child: hasAvatar
                    ? null
                    : Text(
                        ChatUserHelper.initials(widget.user),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ChatUserHelper.displayName(widget.user),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.user.isOnline
                              ? AppColors.successColor
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.user.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.user.isOnline
                              ? AppColors.successColor
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Audio call',
          icon: const Icon(Icons.call_rounded, color: Colors.white),
          onPressed: () => _showCallPlaceholder('Audio'),
        ),
        IconButton(
          tooltip: 'Video call',
          icon: const Icon(Icons.videocam_rounded, color: Colors.white),
          onPressed: () => _showCallPlaceholder('Video'),
        ),
        PopupMenuButton<_ChatMenuAction>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (action) => _handleChatMenuAction(action),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _ChatMenuAction.viewContact,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline_rounded),
                title: Text('View contact'),
              ),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.muteToggle,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                ),
                title: Text(_isMuted ? 'Unmute chat' : 'Mute chat'),
              ),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.archiveToggle,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(_isArchived ? 'Unarchive chat' : 'Archive chat'),
              ),
            ),
            const PopupMenuItem(
              value: _ChatMenuAction.clearChat,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cleaning_services_outlined),
                title: Text('Clear chat'),
              ),
            ),
            const PopupMenuItem(
              value: _ChatMenuAction.blockUser,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.block_rounded),
                title: Text('Block user'),
              ),
            ),
            const PopupMenuItem(
              value: _ChatMenuAction.reportUser,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.flag_outlined),
                title: Text('Report user'),
              ),
            ),
          ],
        ),
      ],
      backgroundColor: AppColors.primaryGreen,
    );
  }

  // ============ CALL PLACEHOLDER ============
  void _showCallPlaceholder(String kind) {
    final name = ChatUserHelper.displayName(widget.user);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$kind call to $name — coming soon'),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ============ POPUP MENU HANDLER ============
  Future<void> _handleChatMenuAction(_ChatMenuAction action) async {
    switch (action) {
      case _ChatMenuAction.viewContact:
        _showContactSheet();
        break;

      case _ChatMenuAction.muteToggle:
        if (_isMuted) {
          await Apis.unmuteChat(otherUserId: widget.user.id);
          if (!mounted) return;
          setState(() => _isMuted = false);
          _showSnackBar('Chat unmuted', isSuccess: true);
        } else {
          final duration = await _showMuteDurationSheet();
          if (duration == null) return;
          await Apis.muteChat(otherUserId: widget.user.id, duration: duration);
          if (!mounted) return;
          setState(() => _isMuted = true);
          _showSnackBar('Chat muted', isSuccess: true);
        }
        break;

      case _ChatMenuAction.archiveToggle:
        if (_isArchived) {
          await Apis.unarchiveChat(otherUserId: widget.user.id);
          if (!mounted) return;
          setState(() => _isArchived = false);
          _showSnackBar('Chat unarchived', isSuccess: true);
        } else {
          await Apis.archiveChat(otherUserId: widget.user.id);
          if (!mounted) return;
          setState(() => _isArchived = true);
          _showSnackBar('Chat archived', isSuccess: true);
        }
        break;

      case _ChatMenuAction.clearChat:
        final ok = await _confirmDialog(
          title: 'Clear this chat?',
          message: 'Messages will be removed from your view.',
          confirmLabel: 'Clear',
          danger: true,
        );
        if (ok && mounted) {
          setState(() => _messages = []);
          _showSnackBar('Chat cleared', isSuccess: true);
        }
        break;

      case _ChatMenuAction.blockUser:
        final ok = await _confirmDialog(
          title: 'Block ${ChatUserHelper.displayName(widget.user)}?',
          message:
              'You will not receive messages from this user. '
              'You can unblock them from Settings → Blocked users.',
          confirmLabel: 'Block',
          danger: true,
        );
        if (!ok) return;

        await Apis.blockUser(widget.user.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${ChatUserHelper.displayName(widget.user)} blocked',
              ),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        Navigator.of(context).pop();
        break;

      case _ChatMenuAction.reportUser:
        final ok = await _confirmDialog(
          title: 'Report ${ChatUserHelper.displayName(widget.user)}?',
          message: 'Are you sure you want to report this user?',
          confirmLabel: 'Report',
          danger: true,
        );
        if (ok) {
          await Apis.reportUser(
            userId: widget.user.id,
            reason: 'Reported from chat screen',
          );
          if (!mounted) return;
          _showSnackBar('Reported. Thank you.', isSuccess: true);
        }
        break;
    }
  }

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

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.errorColor)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showContactSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              ChatUserHelper.displayName(widget.user),
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 8),
            Text(
              widget.user.email.isEmpty ? 'No email' : widget.user.email,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.user.about.isEmpty ? 'No status' : widget.user.about,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // ============ MESSAGE LIST ============
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _currentUserId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primaryGreen : AppColors.cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildMessageContent(message, isMe),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white70
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message.messageStatus),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============ MESSAGE CONTENT (UPDATED — image tappable + Hero) ============
  Widget _buildMessageContent(Message message, bool isMe) {
    final type = message.fileType;
    final url = message.fileUrl;

    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: isMe ? Colors.white70 : AppColors.textSecondary,
        ),
      );
    }

    if (type == 'image' && url.isNotEmpty) {
      final thumb = CloudinaryService.previewUrl(url);
      // Unique Hero tag per message
      final heroTag =
          'chat-image-${message.senderId}-${message.timestamp.millisecondsSinceEpoch}';

      return GestureDetector(
        onTap: () => _openChatImage(imageUrl: url, heroTag: heroTag),
        child: Hero(
          tag: heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: thumb,
              width: 220,
              fit: BoxFit.cover,
              placeholder: (c, u) => const SizedBox(
                width: 220,
                height: 160,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (c, u, e) =>
                  const Icon(Icons.broken_image, size: 60),
            ),
          ),
        ),
      );
    }

    if (type == 'document' && url.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: isMe ? Colors.white : AppColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.fileName.isNotEmpty ? message.fileName : 'Document',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    if (type == 'audio' && url.isNotEmpty) {
      return AudioMessageBubble(audioUrl: url, isMe: isMe);
    }

    return Text(
      message.text,
      style: TextStyle(
        fontSize: 15,
        color: isMe ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.schedule, size: 14, color: Colors.white70);
      case 'sent':
        return const Icon(Icons.done, size: 14, color: Colors.white70);
      case 'delivered':
        return const Icon(Icons.done_all, size: 14, color: Colors.white70);
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: Colors.lightBlue);
      default:
        return const SizedBox();
    }
  }

  // ============ INPUT ============
  Widget _buildMessageInput() {
    if (_iBlockedThem) return _buildBlockedBanner();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isUploading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Uploading to Cloudinary...'),
              ],
            ),
          ),

        if (_isRecording) _buildRecordingBanner(),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppColors.cardBackground,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    enabled: !_isRecording,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      prefixIcon: IconButton(
                        onPressed: _toggleEmojiPicker,
                        icon: Icon(
                          _showEmoji
                              ? Icons.keyboard
                              : Icons.emoji_emotions_outlined,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      suffixIcon: IconButton(
                        onPressed: _isUploading ? null : _showAttachmentSheet,
                        icon: const Icon(
                          Icons.attach_file,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  final showSend = hasText || _isRecording;

                  return Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isSending
                          ? null
                          : () {
                              if (_isRecording) {
                                _stopAndSendRecording();
                              } else if (hasText) {
                                _sendMessage();
                              } else {
                                _startRecording();
                              }
                            },
                      icon: _isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              showSend
                                  ? (_isRecording
                                        ? Icons.stop
                                        : Icons.send_rounded)
                                  : Icons.mic,
                              color: Colors.white,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        if (_showEmoji && !_isRecording)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              textEditingController: _messageController,
              scrollController: ScrollController(),
              onEmojiSelected: (category, emoji) {},
              onBackspacePressed: () {
                final text = _messageController.text;
                if (text.isNotEmpty) {
                  _messageController.text = text.substring(0, text.length - 1);
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _messageController.text.length),
                  );
                }
              },
              config: Config(
                height: 280,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28,
                  backgroundColor: AppColors.cardBackground,
                  noRecents: const Text(
                    'No Recents',
                    style: TextStyle(fontSize: 20, color: Colors.black26),
                    textAlign: TextAlign.center,
                  ),
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: AppColors.cardBackground,
                  indicatorColor: AppColors.primaryGreen,
                  iconColorSelected: AppColors.primaryGreen,
                  backspaceColor: AppColors.primaryGreen,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: true,
                  showBackspaceButton: true,
                  showSearchViewButton: true,
                ),
                searchViewConfig: const SearchViewConfig(
                  backgroundColor: Color(0xFFF2F2F2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBlockedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: AppColors.errorColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: AppColors.errorColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You blocked this contact. Unblock them from '
              'Settings → Blocked users to send messages.',
              style: TextStyle(
                color: AppColors.errorColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.errorColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Recording… $_recordDuration',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _stopAndSendRecording(cancel: true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    if (_isOnline) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Colors.red.withValues(alpha: 0.2),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.red),
          SizedBox(width: 8),
          Text(
            'You\'re offline - Messages will send when online',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildOfflineBanner(),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet\nSay hello to ${ChatUserHelper.displayName(widget.user)}',
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess
              ? AppColors.successColor
              : AppColors.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _recordTimer?.cancel();

    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }
}
