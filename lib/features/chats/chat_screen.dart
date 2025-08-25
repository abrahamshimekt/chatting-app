import 'package:flutter/material.dart';
import 'chat_repo.dart';
import '../../core/supa.dart';
import 'conversation_model.dart';

class ChatScreen extends StatefulWidget {
  final String convId; // UUID
  final bool autofocusComposer;
  const ChatScreen({
    super.key,
    required this.convId,
    this.autofocusComposer = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final repo = ChatRepo();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  bool _showJumpToBottom = false;

  UserLite? _other;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _hydrateHeader();
    if (widget.autofocusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _inputFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _hydrateHeader() async {
    final u = await repo.otherUserInDirect(widget.convId);
    if (!mounted) return;
    setState(() => _other = u);
  }

  void _onScroll() {
    final atBottom = _scroll.position.pixels <= 48.0; 
    setState(() => _showJumpToBottom = !atBottom);
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final me = supa.auth.currentUser!.id;

    final title = _other?.name ?? 'Chat';
    final avatar = CircleAvatar(
      radius: 16,
      backgroundImage:
          (_other?.avatarUrl != null && _other!.avatarUrl!.isNotEmpty) ? NetworkImage(_other!.avatarUrl!) : null,
      child: (_other?.avatarUrl == null || _other!.avatarUrl!.isEmpty)
          ? Text(title.isNotEmpty ? title[0].toUpperCase() : '?')
          : null,
    );

    final media = MediaQuery.of(context);
    final clamped = media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: 1.15));

    return MediaQuery(
      data: clamped,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 4),
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: repo.messages(widget.convId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final raw = snap.data ?? const [];
                  final msgs = raw.toList(growable: false);

                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: msgs.length,
                        itemBuilder: (context, index) {
                          final m = msgs[index];
                          final mine = m['author_id'] == me;
                          final time = _parseTs(m['created_at']);
                          final text = (m['body'] as String?) ?? '';
                          return _MessageBubble(
                            text: text,
                            mine: mine,
                            time: time,
                          );
                        },
                      ),
                      if (msgs.isEmpty) const Center(child: Text('Say hello 👋')),
                    ],
                  );
                },
              ),
            ),
            _Composer(
              controller: _text,
              focusNode: _inputFocus,
              onSend: (t) async {
                final text = t.trim();
                if (text.isEmpty) return;
                _text.clear();
                await repo.send(widget.convId, text);
                _jumpToBottom();
                _inputFocus.requestFocus();
              },
            ),
          ],
        ),
        floatingActionButton: _showJumpToBottom
            ? FloatingActionButton(
                onPressed: _jumpToBottom,
                child: const Icon(Icons.arrow_downward),
              )
            : null,
      ),
    );
  }

  DateTime? _parseTs(dynamic ts) {
    if (ts is String) return DateTime.tryParse(ts);
    if (ts is DateTime) return ts;
    return null;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.mine,
    required this.time,
  });

  final String text;
  final bool mine;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mine ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                ),
              ),
              if (time != null) ...[
                const SizedBox(height: 4),
                Text(
                  _fmtTime(time!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        bottom: 6,
        left: mine ? 60 : 8,
        right: mine ? 8 : 60,
      ),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) const SizedBox(width: 28),
          bubble,
          if (mine) const SizedBox(width: 28),
        ],
      ),
    );
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final mer = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$mm $mer';
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Future<void> Function(String text) onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    final can = widget.controller.text.trim().isNotEmpty;
    if (can != _canSend) setState(() => _canSend = can);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(.15))),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Attach',
              onPressed: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Attachment picker (todo)')));
              },
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                focusNode: widget.focusNode,
                controller: widget.controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) {
                  if (_canSend) widget.onSend(v);
                },
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _canSend ? () => widget.onSend(widget.controller.text) : null,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
