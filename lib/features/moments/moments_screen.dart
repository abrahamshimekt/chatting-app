import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/supa.dart';
import 'moments_repo.dart';
import 'moment_model.dart';
import 'moment_editor.dart';

class MomentsScreen extends StatelessWidget {
  final String? userId;
  const MomentsScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final uid = userId ?? supa.auth.currentUser!.id;
    final repo = MomentsRepo();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final useGrid = w >= 680;
        final cols = w >= 1100 ? 3 : 2;

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(userId == null ? 'My Moments' : 'Moments'),
                centerTitle: true,
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              body: StreamBuilder<List<Moment>>(
                stream: repo.myMoments(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return _EmptyState(
                      onCreate: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) =>
                              MomentEditor(repo: repo, authorId: uid),
                        );
                      },
                    );
                  }

                  if (!useGrid) {
                    // Phone: list
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _MomentCard(moment: items[i], repo: repo),
                    );
                  } else {
                    // Wide: grid
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 4 / 3,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) =>
                          _MomentCard(moment: items[i], repo: repo),
                    );
                  }
                },
              ),
            ),
            if (userId == null || userId == supa.auth.currentUser!.id)
              DraggableFloatingActionButton(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => MomentEditor(repo: repo, authorId: uid),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.panorama_outlined,
              size: 56,
              color: t.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('No moments yet', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Share a photo, video, or thought to get started.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create moment'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentCard extends StatefulWidget {
  const _MomentCard({required this.moment, required this.repo});
  final Moment moment;
  final MomentsRepo repo;

  @override
  State<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<_MomentCard> {
  bool _hasLiked = false;
  int _likesCount = 0;
  int _viewersCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialize counts
    _likesCount = widget.moment.likesCount ?? 0;
    _viewersCount = widget.moment.viewersCount ?? 0;
    // Increment view count and check like status
    final userId = supa.auth.currentUser?.id;
    if (userId != null) {
      widget.repo.incrementViewCount(widget.moment.id, userId).then((_) {
        if (mounted) {
          widget.repo.getViewersCount(widget.moment.id).then((count) {
            if (mounted) setState(() => _viewersCount = count);
          });
        }
      });
      widget.repo.hasLiked(widget.moment.id, userId).then((liked) {
        if (mounted) setState(() => _hasLiked = liked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isOwner = supa.auth.currentUser?.id == widget.moment.authorId;

    final media = switch (widget.moment.mediaType) {
      'image' => _ImageCard(url: widget.moment.mediaUrl!),
      'video' => _VideoPlayerCard(url: widget.moment.mediaUrl!),
      _ => const SizedBox.shrink(),
    };

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((widget.moment.text ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Text(widget.moment.text!, style: t.textTheme.bodyLarge),
            ),
          if (widget.moment.mediaType != 'none')
            Padding(padding: const EdgeInsets.all(8), child: media),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 8, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Like ($_likesCount)',
                    icon: Icon(
                      _hasLiked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: _hasLiked
                          ? t.colorScheme.error
                          : t.colorScheme.primary,
                    ),
                    onPressed: () async {
                      final userId = supa.auth.currentUser?.id;
                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Please log in to like this moment',
                            ),
                            backgroundColor: t.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                        return;
                      }
                      try {
                        if (_hasLiked) {
                          await widget.repo.unlikeMoment(
                            widget.moment.id,
                            userId,
                          );
                          if (mounted) setState(() => _likesCount--);
                        } else {
                          await widget.repo.likeMoment(
                            widget.moment.id,
                            userId,
                          );
                          if (mounted) setState(() => _likesCount++);
                        }
                        if (mounted) setState(() => _hasLiked = !_hasLiked);
                      } catch (e) {
                        if (mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to ${_hasLiked ? 'unlike' : 'like'} moment: $e',
                              ),
                              backgroundColor: t.colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Message',
                    icon: Icon(
                      Icons.message,
                      size: 20,
                      color: t.colorScheme.primary,
                    ),
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) => _CommentDialog(
                          momentId: widget.moment.id,
                          repo: widget.repo,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Viewers ($_viewersCount)',
                    icon: Icon(
                      Icons.visibility,
                      size: 20,
                      color: t.colorScheme.primary,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Viewers list not implemented'),
                          backgroundColor: t.colorScheme.primary,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Share',
                    icon: Icon(
                      Icons.share,
                      size: 20,
                      color: t.colorScheme.primary,
                    ),
                    onPressed: () {
                      final txt = widget.moment.text ?? '';
                      final url = widget.moment.mediaUrl ?? '';
                      final shareText = [
                        txt,
                        url,
                      ].where((s) => s.isNotEmpty).join('\n');
                      // ignore: deprecated_member_use
                      if (shareText.isNotEmpty) Share.share(shareText);
                    },
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Edit',
                      icon: Icon(
                        Icons.edit,
                        size: 20,
                        color: t.colorScheme.primary,
                      ),
                      onPressed: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => MomentEditor(
                            repo: widget.repo,
                            authorId: widget.moment.authorId,
                            existing: widget.moment,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: t.colorScheme.error,
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete moment?'),
                            content: const Text(
                              'This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: t.colorScheme.error,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await widget.repo.deleteMoment(widget.moment.id);
                        }
                      },
                    ),
                  ],
                  const SizedBox(width: 2),
                  Text(
                    _relativeTime(widget.moment.updatedAt),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final local = t.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = (local.hour % 12 == 0 ? 12 : local.hour % 12).toString();
    final mm = local.minute.toString().padLeft(2, '0');
    final mer = local.hour >= 12 ? 'PM' : 'AM';
    return '$y-$mo-$d $hh:$mm $mer';
  }
}

class _CommentDialog extends StatefulWidget {
  final String momentId;
  final MomentsRepo repo;

  const _CommentDialog({required this.momentId, required this.repo});

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final userId = supa.auth.currentUser?.id;

    return AlertDialog(
      title: const Text('Comments'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: StreamBuilder<List<MomentComment>>(
                stream: widget.repo.getComments(widget.momentId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snap.data ?? [];
                  if (comments.isEmpty) {
                    return Text(
                      'No comments yet.',
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: comments.length,
                    itemBuilder: (context, i) {
                      final comment = comments[i];
                      return ListTile(
                        title: Text(
                          comment.body,
                          style: t.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          _relativeTime(comment.createdAt),
                          style: t.textTheme.bodySmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: 'Add a comment',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: t.colorScheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Comment cannot be empty';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate() || userId == null) return;
            try {
              await widget.repo.createComment(
                momentId: widget.momentId,
                authorId: userId,
                body: _commentController.text,
              );
              if (mounted) {
                _commentController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Comment added!'),
                    backgroundColor: t.colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to add comment: $e'),
                    backgroundColor: t.colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            }
          },
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Post'),
        ),
      ],
    );
  }

  String _relativeTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final local = t.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = (local.hour % 12 == 0 ? 12 : local.hour % 12).toString();
    final mm = local.minute.toString().padLeft(2, '0');
    final mer = local.hour >= 12 ? 'PM' : 'AM';
    return '$y-$mo-$d $hh:$mm $mer';
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
        ),
      ),
    );
  }
}

class _VideoPlayerCard extends StatefulWidget {
  const _VideoPlayerCard({required this.url});
  final String url;

  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  late final VideoPlayerController _vc = VideoPlayerController.networkUrl(
    Uri.parse(widget.url),
  );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _vc.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _vc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || !_vc.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _vc.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_vc),
            Align(
              alignment: Alignment.center,
              child: IconButton(
                icon: Icon(
                  _vc.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 56,
                  color: Colors.white,
                ),
                onPressed: () => setState(() {
                  _vc.value.isPlaying ? _vc.pause() : _vc.play();
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DraggableFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;

  const DraggableFloatingActionButton({super.key, required this.onPressed});

  @override
  State<DraggableFloatingActionButton> createState() =>
      _DraggableFloatingActionButtonState();
}

class _DraggableFloatingActionButtonState
    extends State<DraggableFloatingActionButton> {
  late Offset position;

  @override
  void initState() {
    super.initState();
    // Initialize position at bottom-right with 16-pixel padding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;
      setState(() {
        position = Offset(
          screenSize.width - 80 - 16, // FAB width ~80, padding 16
          screenSize.height - 80 - 16, // FAB height ~80, padding 16
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Update position based on drag delta
            final newX = (position.dx + details.delta.dx).clamp(
              0.0,
              MediaQuery.of(context).size.width - 80,
            );
            final newY = (position.dy + details.delta.dy).clamp(
              0.0,
              MediaQuery.of(context).size.height - 80,
            );
            position = Offset(newX, newY);
          });
        },
        child: FloatingActionButton.extended(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.add),
          label: const Text('New'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: t.colorScheme.primary,
          foregroundColor: t.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
