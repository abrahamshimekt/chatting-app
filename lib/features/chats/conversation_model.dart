class Conversation {
  final String id;
  final bool isGroup;
  final String? title;
  final DateTime? lastMessageAt;
  final DateTime? updatedAt;

  Conversation({
    required this.id,
    required this.isGroup,
    this.title,
    this.lastMessageAt,
    this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        isGroup: (j['is_group'] as bool?) ?? false,
        title: j['title'] as String?,
        lastMessageAt: _parseTs(j['last_message_at']),
        updatedAt: _parseTs(j['updated_at']),
      );
}

class ConversationMember {
  final String convId;
  final String userId;
  final String role;

  ConversationMember({
    required this.convId,
    required this.userId,
    required this.role,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> j) => ConversationMember(
        convId: j['conv_id'] as String,
        userId: j['user_id'] as String,
        role: (j['role'] as String?) ?? 'member',
      );
}

class UserLite {
  final String id;
  final String name;
  final String gender;
  final String? avatarUrl;
  final DateTime? lastSeen;

  UserLite({
    required this.id,
    required this.name,
    required this.gender,
    this.avatarUrl,
    this.lastSeen,
  });
}

DateTime? _parseTs(dynamic v) {
  if (v is String) return DateTime.tryParse(v);
  if (v is DateTime) return v;
  return null;
}
