// lib/screens/chat_screen.dart

// ignore_for_file: unnecessary_null_comparison, deprecated_member_use, file_names, avoid_print

import 'dart:async';
import 'dart:io';

import 'package:chat_app/models/usermodel.dart';
import 'package:chat_app/models/message_model.dart';
import 'package:chat_app/api/database_service/database_service.dart';
import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/helper/connectivity_helper.dart';
import 'package:chat_app/helper/chat_user.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final ImagePicker _picker = ImagePicker(); // ✅ single instance

  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  List<Message> _messages = [];
  bool _isOnline = true;
  String _currentUserId = '';
  bool _isSending = false;
  bool _isUploading = false; // ✅ for attachments

  // ✅ Emoji state
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadMessages();
    _setupConnectivityListener();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
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
        _focusNode.unfocus();
        if (_showEmoji) setState(() => _showEmoji = false);
        _scrollToBottom();
        if (!_isOnline) {
          _showSnackBar('💾 Saved. Will send when online.', isSuccess: true);
        }
      } else {
        _showSnackBar('❌ Failed to send', isSuccess: false);
      }
    } catch (e) {
      _showSnackBar('❌ Error: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ============ UPLOAD & SEND ATTACHMENT ============
  Future<void> _uploadAndSendFile({
    required File file,
    required String type, // 'image' | 'document'
    String? fileName,
  }) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final ext = file.path.split('.').last;
      final storagePath =
          'chat_attachments/${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Use the API's existing message method; attachment-specific sending is
      // not exposed by Apis.
      final success = await Apis.sendMessage(
        receiverId: widget.user.id,
        messageText: downloadUrl,
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
        imageQuality: 70,
      );
      if (picked == null) return;
      await _uploadAndSendFile(file: File(picked.path), type: 'image');
    } catch (e) {
      _showSnackBar('❌ Gallery error: $e', isSuccess: false);
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (picked == null) return;
      await _uploadAndSendFile(file: File(picked.path), type: 'image');
    } catch (e) {
      _showSnackBar('❌ Camera error: $e', isSuccess: false);
    }
  }

  // ============ FIXED: _pickDocument() ============
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);

      // ✅ Proper null and empty check
      if (result == null || result.isEmpty) return;

      // ✅ Use .first instead of .single for cleaner code
      final file = result.first;
      final path = file.path;

      // ✅ Null-check the path
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

  // ============ APP BAR ============
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
            backgroundImage: widget.user.image.trim().isNotEmpty
                ? CachedNetworkImageProvider(widget.user.image)
                : null,
            child: widget.user.image.trim().isEmpty
                ? Text(
                    ChatUserHelper.initials(widget.user),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
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
      backgroundColor: AppColors.primaryGreen,
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

  // ============ MESSAGE CONTENT ============
  Widget _buildMessageContent(Message message, bool isMe) {
    // Uses `dynamic` casts so it compiles even if model isn't updated yet.
    // Once Message has fileUrl/fileType, remove `as dynamic`.
    final type = (message as dynamic).fileType?.toString() ?? 'text';
    final url = (message as dynamic).fileUrl?.toString();

    if (type == 'image' && url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 220,
          fit: BoxFit.cover,
          placeholder: (c, u) => const SizedBox(
            width: 220,
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (c, u, e) => const Icon(Icons.broken_image, size: 60),
        ),
      );
    }

    if (type == 'document' && url != null && url.isNotEmpty) {
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
              message.text.isNotEmpty ? message.text : 'Document',
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

    // default: text
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ Upload progress banner
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
                Text('Uploading attachment...'),
              ],
            ),
          ),

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
              Container(
                margin: const EdgeInsets.only(left: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _isSending ? null : _sendMessage,
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
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        if (_showEmoji)
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

    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
