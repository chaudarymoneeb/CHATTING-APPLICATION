// lib/screens/settings_screen.dart

// ignore_for_file: duplicate_import

import 'package:chat_app/api/api.dart';
import 'package:chat_app/app_constant.dart';
import 'package:chat_app/screens/blocked_users_screen.dart';
import 'package:chat_app/screens/blocked_users_screen.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _sounds = true;
  bool _readReceipts = true;
  bool _mediaAutoDownload = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: AppTextStyles.heading2),
      ),
      body: ListView(
        children: [
          const _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Push notifications'),
            subtitle: const Text('Get alerts for new messages'),
            activeThumbColor: AppColors.primaryGreen,
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          SwitchListTile(
            title: const Text('Sounds'),
            subtitle: const Text('Play sounds for messages'),
            activeThumbColor: AppColors.primaryGreen,
            value: _sounds,
            onChanged: (v) => setState(() => _sounds = v),
          ),

          const Divider(height: 1),
          const _SectionHeader('Privacy'),
          SwitchListTile(
            title: const Text('Read receipts'),
            subtitle: const Text('Let others know when you read a message'),
            activeThumbColor: AppColors.primaryGreen,
            value: _readReceipts,
            onChanged: (v) => setState(() => _readReceipts = v),
          ),

          // ✅ Blocked users entry with live count
          StreamBuilder(
            stream: Apis.blockedUsersStream(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: AppColors.primaryGreen,
                ),
                title: const Text('Blocked users'),
                subtitle: Text(
                  count == 0 ? 'No one is blocked' : '$count blocked',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen(),
                    ),
                  );
                },
              );
            },
          ),

          const Divider(height: 1),
          const _SectionHeader('Data & storage'),
          SwitchListTile(
            title: const Text('Auto-download media'),
            subtitle: const Text('Only on Wi-Fi'),
            activeThumbColor: AppColors.primaryGreen,
            value: _mediaAutoDownload,
            onChanged: (v) => setState(() => _mediaAutoDownload = v),
          ),

          const Divider(height: 1),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(
              Icons.info_outline_rounded,
              color: AppColors.primaryGreen,
            ),
            title: Text('App version'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      label.toUpperCase(),
      style: AppTextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: AppColors.primaryGreen,
      ),
    ),
  );
}
