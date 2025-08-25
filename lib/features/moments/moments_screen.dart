import 'dart:io';
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
        final useGrid = w >= 680; // switch to grid on tablets/desktop
        final cols = w >= 1100 ? 3 : 2;

        return Scaffold(
          appBar: AppBar(title: Text(userId == null ? 'My Moments' : 'Moments')),
          body: StreamBuilder<List<Moment>>(
            stream: repo.myMoments(uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return _EmptyState(onCreate: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => MomentEditor(repo: repo, authorId: uid),
                  );
                });
              }

              if (!useGrid) {
                // Phone: list
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _MomentCard(moment: items[i], repo: repo),
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
                  itemBuilder: (context, i) => _MomentCard(moment: items[i], repo: repo),
                );
              }
            },
          ),
          floatingActionButton: (userId == null || userId == supa.auth.currentUser!.id)
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                  onPressed: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => MomentEditor(repo: repo, authorId: uid),
                    );
                  },
                )
              : null,
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
            Icon(Icons.panorama_outlined, size: 56, color: t.colorScheme.primary),
            const SizedBox(height: 12),
            Text('No moments yet', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Share a photo, video, or thought to get started.',
                style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create moment')),
          ],
        ),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment, required this.repo});
  final Moment moment;
  final MomentsRepo repo;

  bool get _isOwner => supa.auth.currentUser?.id == moment.authorId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final media = switch (moment.mediaType) {
      'image' => _ImageCard(url: moment.mediaUrl!),
      'video' => _VideoPlayerCard(url: moment.mediaUrl!),
      _ => const SizedBox.shrink(),
    };

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((moment.text ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Text(moment.text!, style: t.textTheme.bodyLarge),
            ),
          if (moment.mediaType != 'none') Padding(padding: const EdgeInsets.all(8), child: media),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(
              children: [
                Text(_relativeTime(moment.updatedAt),
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const Spacer(),
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    final txt = moment.text ?? '';
                    final url = moment.mediaUrl ?? '';
                    final shareText = [txt, url].where((s) => s.isNotEmpty).join('\n');
                    if (shareText.isNotEmpty) Share.share(shareText);
                  },
                ),
                if (_isOwner)
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => MomentEditor(
                          repo: repo,
                          authorId: moment.authorId,
                          existing: moment,
                        ),
                      );
                    },
                  ),
                if (_isOwner)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete moment?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await repo.deleteMoment(moment.id);
                    },
                  ),
              ],
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
    // Fallback: yyyy-mm-dd hh:mm
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
          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
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
  late final VideoPlayerController _vc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
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
        child: const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator())),
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
                icon: Icon(_vc.value.isPlaying ? Icons.pause_circle : Icons.play_circle, size: 56, color: Colors.white),
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
