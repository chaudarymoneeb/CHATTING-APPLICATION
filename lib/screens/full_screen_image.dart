import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullScreenImage extends StatelessWidget {
  final String? imageBase64;
  final String? imageUrl;
  final File? imageFile;
  final String heroTag; // unique tag for Hero animation
  final String? senderName; // optional: WhatsApp jaisa top pe naam

  const FullScreenImage({
    super.key,
    this.imageBase64,
    this.imageUrl,
    this.imageFile,
    this.heroTag = 'fullscreen-image',
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: senderName != null
            ? Text(
                senderName!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: _buildImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    // Priority: File > Base64 > URL
    if (imageFile != null) {
      return Image.file(imageFile!, fit: BoxFit.contain);
    }

    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(imageBase64!);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {}
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white, size: 120),
      );
    }

    return const Icon(Icons.person, color: Colors.white, size: 120);
  }
}
