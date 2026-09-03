class ChatUser {
  const ChatUser({
    required this.image,
    required this.about,
    required this.name,
    required this.createdAt,
    required this.isOnline,
    required this.id,
    required this.pushToken,
    required this.email,
    required this.lastActive,
  });
  final String image;
  final String about;
  final String name;
  final String createdAt;
  final bool isOnline;
  final String id;
  final String pushToken;
  final String email;
  final String lastActive;

  factory ChatUser.fromJson(Map<String, dynamic> json, String docId) =>
      ChatUser(
        image: _asString(json['image']),
        about: _asString(json['about']),
        name: _asString(json['name']),
        createdAt: _asString(json['created_at']),
        isOnline: json['is_online'] == true,
        id: docId,
        pushToken: _asString(json['push_token']),
        email: _asString(json['email']),
        lastActive: _asString(json['last_active']),
      );

  static String _asString(dynamic value) => value?.toString() ?? '';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'image': image,
      'about': about,
      'name': name,
      'created_at': createdAt,
      'is_online': isOnline,
      'id': id,
      'push_token': pushToken,
      'email': email,
      'last_active': lastActive,
    };
  }
}
