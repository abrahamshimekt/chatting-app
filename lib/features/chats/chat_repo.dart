import 'dart:async';
import '../../core/supa.dart';
import 'conversation_model.dart';

class ChatRepo {
  // ---------------------------
  // Helpers
  // ---------------------------

  DateTime? _parseTsLocal(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    if (v is DateTime) return v;
    return null;
  }

  // ---------------------------
  // Profiles / Users
  // ---------------------------

  Future<bool> userExists(String userId) async {
    final row = await supa
        .from('profiles')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  // ---------------------------
  // Direct conversation upsert (via SECURITY DEFINER RPC)
  // ---------------------------

  Future<String> upsertDirectConversation(String otherUserId) async {
    final me = supa.auth.currentUser!.id;

    // Optional self-DM rule: allow or block
    // if (me == otherUserId) throw StateError('Cannot chat with yourself.');

    final res = await supa.rpc(
      'upsert_direct_conversation',
      params: {'a': me, 'b': otherUserId},
    );

    if (res is! String) {
      throw StateError('Unexpected RPC response: $res');
    }
    return res; // UUID
  }

  // ---------------------------
  // Conversations list (polling JOIN; RLS-friendly)
  // ---------------------------

  /// Emits my conversations every [interval]. Uses a single JOIN query (no .in_ / .filter on streams).
  Stream<List<Conversation>> myConversations({
    Duration interval = const Duration(seconds: 2),
  }) async* {
    yield await _fetchMyConversationsOnceJoin();
    yield* Stream.periodic(interval).asyncMap((_) => _fetchMyConversationsOnceJoin());
  }

  Future<List<Conversation>> _fetchMyConversationsOnceJoin() async {
    final me = supa.auth.currentUser!.id;

    // JOIN conversations with conversation_members where user_id = me
    final rows = await supa
        .from('conversations')
        .select(
          'id, is_group, title, last_message_at, updated_at, conversation_members!inner(user_id)',
        )
        .eq('conversation_members.user_id', me);

    final list = <Conversation>[];
    for (final r in rows.cast<Map<String, dynamic>>()) {
      list.add(Conversation.fromJson(r));
    }
  
    // Sort newest first (last_message_at, then updated_at)
    list.sort((a, b) {
      final at = a.lastMessageAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastMessageAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });

    return list;
  }

  // ---------------------------
  // Messages (true realtime stream)
  // ---------------------------

  Stream<List<Map<String, dynamic>>> messages(String convId) {
    return supa
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conv_id', convId)
        .order('created_at'); // ascending; UI should reverse
  }

  Future<void> send(String convId, String text) async {
    final me = supa.auth.currentUser!.id;

    await supa.from('messages').insert({
      'conv_id': convId,
      'author_id': me,
      'body': text,
    });

    final nowIso = DateTime.now().toIso8601String();
    await supa
        .from('conversations')
        .update({'last_message_at': nowIso, 'updated_at': nowIso})
        .eq('id', convId);
  }

  Future<Map<String, dynamic>?> latestMessage(String convId) async {
    final rows = await supa
        .from('messages')
        .select('id, body, author_id, created_at')
        .eq('conv_id', convId)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isNotEmpty) {
      return rows.first;
    }
    return null;
  }

  // ---------------------------
  // Direct chat helpers
  // ---------------------------

  /// Returns the other user in a direct (1:1) conversation.
  Future<UserLite?> otherUserInDirect(String convId) async {
    final me = supa.auth.currentUser!.id;

    final rows = await supa
        .from('conversation_members')
        .select('user_id, conversations!inner(is_group)')
        .eq('conv_id', convId);

    if (rows.length != 2) return null;
    final isGroup = (rows.first as Map)['conversations']['is_group'] == true;
    if (isGroup) return null;

    String? other;
    for (final r in rows.cast<Map<String, dynamic>>()) {
      final uid = r['user_id'] as String;
      if (uid != me) other = uid;
    }
    if (other == null) return null;

    return getUserLite(other);
  }

  /// Minimal profile for headers, tiles, etc.
  Future<UserLite?> getUserLite(String userId) async {
    final row = await supa
        .from('profiles')
        .select('user_id, display_name, gender, avatar_url, last_seen')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;

    return UserLite(
      id: row['user_id'] as String,
      name: (row['display_name'] as String?)?.trim().isNotEmpty == true
          ? row['display_name'] as String
          : 'User ${row['user_id'].toString().substring(0, 6)}',
      gender: (row['gender'] as String?) ?? '',
      avatarUrl: row['avatar_url'] as String?,
      lastSeen: _parseTsLocal(row['last_seen']),
    );
  }
}
