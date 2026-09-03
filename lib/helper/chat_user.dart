import 'package:chat_app/models/usermodel.dart';

/// Presentation helpers for [ChatUser]s shared by the user list and cards.
class ChatUserHelper {
  const ChatUserHelper._();

  static String displayName(ChatUser user) {
    final name = user.name.trim();
    return name.isEmpty ? 'Unknown user' : name;
  }

  static String initials(ChatUser user) {
    final words = displayName(
      user,
    ).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).take(2);
    final initials = words.map((word) => word[0]).join();
    return initials.isEmpty ? '?' : initials.toUpperCase();
  }

  static bool matches(ChatUser user, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    return user.name.toLowerCase().contains(normalizedQuery) ||
        user.email.toLowerCase().contains(normalizedQuery);
  }
}
