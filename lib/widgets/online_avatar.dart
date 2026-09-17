// lib/widgets/online_avatar.dart
//
// A CircleAvatar with a small online/offline dot badge in the bottom-right
// corner, shared by the home list, the chat card, and the chat app bar so
// the "online status badge" treatment is consistent everywhere.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/app_constant.dart';
import 'package:flutter/material.dart';

class OnlineAvatar extends StatelessWidget {
  const OnlineAvatar({
    super.key,
    required this.imageUrl,
    required this.initials,
    required this.isOnline,
    this.radius = 24,
    this.badgeBorderColor = Colors.white,
  });

  final String imageUrl;
  final String initials;
  final bool isOnline;
  final double radius;
  final Color badgeBorderColor;

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
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: imageUrl.trim().isEmpty
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => fallback,
                      errorWidget: (_, _, _) => fallback,
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
                border: Border.all(color: badgeBorderColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
