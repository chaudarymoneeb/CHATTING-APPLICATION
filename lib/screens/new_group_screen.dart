// lib/screens/new_group_screen.dart

import 'package:chat_app/app_constant.dart';
import 'package:flutter/material.dart';

class NewGroupScreen extends StatelessWidget {
  const NewGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New group', style: AppTextStyles.heading2),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_outlined,
                  size: 48,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Groups coming soon',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Soon you will be able to create group chats with multiple contacts.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
