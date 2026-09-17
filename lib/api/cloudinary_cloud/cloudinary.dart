// lib/services/cloudinary_service.dart
//
// Handles direct HTTP uploads to Cloudinary using an unsigned upload preset.
// Also exposes URL helpers to generate optimized delivery URLs (thumbnail,
// preview, full-res) without re-uploading the asset.

// ignore_for_file: unused_field

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  CloudinaryService._();

  /// Your Cloudinary cloud name (from the dashboard).
  static const String _cloudName = 'a8cb3uvg';

  /// Your unsigned upload preset name (Settings → Upload → Upload presets).
  static const String _uploadPreset = 'wechat_unsigned'; // ← CHANGE THIS

  /// Default folder on Cloudinary where all uploads land.
  static const String _defaultFolder = 'chat_attachments';

  /// Base delivery URL for your cloud.
  static const String _baseDeliveryUrl =
      'https://res.cloudinary.com/$_cloudName';

  // ======================================================================
  // UPLOAD
  // ======================================================================

  /// Uploads a file to Cloudinary and returns the `secure_url`, or null on
  /// failure. Use this for images, documents, audio — anything.
  ///
  /// [resourceType] can be 'image', 'video', 'raw', or 'auto'. Use 'auto'
  /// unless you know the type. Audio must be uploaded as 'video' to enable
  /// playback streaming (Cloudinary treats audio as video internally).
  static Future<String?> uploadFile(
    File file, {
    String resourceType = 'auto',
    String folder = _defaultFolder,
    String? fileName,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder;

      if (fileName != null && fileName.isNotEmpty) {
        request.fields['public_id'] =
            '${DateTime.now().millisecondsSinceEpoch}_${_sanitize(fileName)}';
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final Map<String, dynamic> json =
            jsonDecode(responseBody) as Map<String, dynamic>;
        final url = json['secure_url'] as String?;
        debugPrint('☁️ Cloudinary upload success: $url');
        return url;
      } else {
        debugPrint(
          '❌ Cloudinary upload failed (${streamedResponse.statusCode}): '
          '$responseBody',
        );
        return null;
      }
    } catch (e, st) {
      debugPrint('❌ Cloudinary upload error: $e\n$st');
      return null;
    }
  }

  // ======================================================================
  // URL HELPERS (auto-optimization)
  // ======================================================================

  /// Inserts a transformation segment into a Cloudinary delivery URL.
  ///
  /// e.g. `https://res.cloudinary.com/<cloud>/image/upload/v123/file.jpg`
  /// becomes `https://res.cloudinary.com/<cloud>/image/upload/w_200,h_200,c_fill,q_auto,f_auto/v123/file.jpg`
  static String withTransform(String secureUrl, String transform) {
    if (secureUrl.isEmpty) return secureUrl;
    final marker = '/upload/';
    final idx = secureUrl.indexOf(marker);
    if (idx == -1) return secureUrl;
    final before = secureUrl.substring(0, idx + marker.length);
    final after = secureUrl.substring(idx + marker.length);
    return '$before$transform/$after';
  }

  /// Small avatar-sized thumbnail (used in lists).
  static String thumbnailUrl(String secureUrl) =>
      withTransform(secureUrl, 'w_200,h_200,c_fill,q_auto,f_auto');

  /// Chat bubble preview (used in the chat screen).
  static String previewUrl(String secureUrl) =>
      withTransform(secureUrl, 'w_600,q_auto,f_auto');

  /// Full-resolution original (used for full-screen viewer).
  static String fullUrl(String secureUrl) =>
      withTransform(secureUrl, 'q_auto,f_auto');

  // ======================================================================
  // HELPERS
  // ======================================================================

  static String _sanitize(String name) {
    // Cloudinary public_id allows alphanumerics, -, _, and / only.
    return name.replaceAll(RegExp(r'[^A-Za-z0-9\-_]'), '_');
  }
}
