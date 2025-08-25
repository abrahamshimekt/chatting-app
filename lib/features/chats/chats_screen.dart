import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'chat_repo.dart';
import '../../core/supa.dart';
import 'conversation_model.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ChatRepo();
    final me = supa.auth.currentUser?.id;
    final media = MediaQuery.of(context);
    final clamped = media.copyWith(
      textScaler: media.textScaler.clamp(maxScaleFactor: 1.15),
    );

    Future<void> startNewChat() async {
      if (me == null) return;
      final pickedUserId = await _showUserPicker(context, excludeUserId: me);
      if (pickedUserId == null) return;

      try {
        final convId = await repo.upsertDirectConversation(pickedUserId);
        if (context.mounted) {
          context.push('/chat/$convId', extra: {'autofocus': true});
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot start chat: $e')));
      }
    }

    return MediaQuery(
      data: clamped,
      child: Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: StreamBuilder<List<Conversation>>(
          stream: repo.myConversations(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.isEmpty) {
              return _EmptyState(onStart: startNewChat);
            }

            final convs = snap.data!;
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: convs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = convs[i];
                return _ConversationTile(
                  conversation: c,
                  onTap: () =>
                      context.push('/chat/${c.id}', extra: {'autofocus': true}),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: startNewChat,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('New chat'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('No conversations yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Start messaging your friends and contacts.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Start a chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  final _repo = ChatRepo();
  Map<String, dynamic>? _preview;
  UserLite? _other;

  @override
  void initState() {
    super.initState();
    _loadPreview();
    _loadOther();
  }

  Future<void> _loadPreview() async {
    final row = await _repo.latestMessage(widget.conversation.id);
    if (!mounted) return;
    setState(() => _preview = row);
  }

  Future<void> _loadOther() async {
    if (widget.conversation.isGroup) return; // groups can use title/photo
    final u = await _repo.otherUserInDirect(widget.conversation.id);
    if (!mounted) return;
    setState(() => _other = u);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = (_preview?['body'] as String?) ?? 'Say hello!';
    final time = _preview?['created_at'] as String?;
    String? hhmm;
    if (time != null) {
      final dt = DateTime.tryParse(time);
      if (dt != null) {
        final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final mm = dt.minute.toString().padLeft(2, '0');
        final mer = dt.hour >= 12 ? 'PM' : 'AM';
        hhmm = '$h:$mm $mer';
      }
    }

    final title = widget.conversation.isGroup
        ? (widget.conversation.title ?? 'Group')
        : (_other?.name ?? 'Chat');

    final leading = CircleAvatar(
      backgroundImage:
          (_other?.avatarUrl != null && _other!.avatarUrl!.isNotEmpty)
          ? NetworkImage(_other!.avatarUrl!)
          : null,
      child: (_other?.avatarUrl == null || _other!.avatarUrl!.isEmpty)
          ? Text(title.isNotEmpty ? title[0].toUpperCase() : '?')
          : null,
    );

    return ListTile(
      leading: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hhmm != null)
            Text(
              hhmm,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
        ],
      ),
      onTap: widget.onTap,
    );
  }
}

/// ------- User Picker (bottom sheet) -------

Future<String?> _showUserPicker(
  BuildContext context, {
  required String excludeUserId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _UserPickerSheet(excludeUserId: excludeUserId),
  );
}

class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet({required this.excludeUserId});
  final String excludeUserId;

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  final _queryCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<UserLite> _results = [];

  @override
  void initState() {
    super.initState();
    _runSearch();
    _queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _queryCtrl.text.trim();
    setState(() => _loading = true);

    try {
      final query = supa
          .from('profiles')
          .select('user_id, display_name, gender, avatar_url, last_seen')
          .neq('user_id', widget.excludeUserId);

      if (q.isNotEmpty) {
        await query.ilike('display_name', '%$q%');
      }

      final rows = await query.limit(30);
      final list = <UserLite>[];
      if (rows is List) {
        for (final r in rows) {
          final m = r as Map<String, dynamic>;
          list.add(
            UserLite(
              id: m['user_id'] as String,
              name: (m['display_name'] as String?)?.trim().isNotEmpty == true
                  ? m['display_name'] as String
                  : 'User ${m['user_id'].toString().substring(0, 6)}',
              gender: m["gender"] as String,
              avatarUrl: m['avatar_url'] as String?,
              lastSeen: _parseTs(m['last_seen']), // <-- uses local helper below
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() => _results = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _queryCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search users…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _queryCtrl.clear();
                            _runSearch();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No users found',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final u = _results[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                                ? NetworkImage(u.avatarUrl!)
                                : null,
                            child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                                ? Text(
                                    u.name.isNotEmpty
                                        ? u.name[0].toUpperCase()
                                        : '?',
                                  )
                                : null,
                          ),
                          title: Text(
                            u.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            u.gender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop<String>(u.id),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Local timestamp parser just for this file
DateTime? _parseTs(dynamic v) {
  if (v is String) return DateTime.tryParse(v);
  if (v is DateTime) return v;
  return null;
}
