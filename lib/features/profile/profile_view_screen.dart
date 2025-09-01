import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/supa.dart';
import '../users/users_repo.dart';
import '../social/social_repo.dart';
import '../chats/chat_repo.dart';
import '../calls/call_screen.dart';
import '../moments/moments_screen.dart';

enum _SizeClass { compact, medium, expanded }

_SizeClass _classOf(BoxConstraints c) {
  final w = c.maxWidth;
  if (w >= 1100) return _SizeClass.expanded;
  if (w >= 700) return _SizeClass.medium;
  return _SizeClass.compact;
}

double _maxContentWidth(_SizeClass sc) =>
    sc == _SizeClass.expanded ? 1000 : 720;

EdgeInsets _hPad(_SizeClass sc) {
  switch (sc) {
    case _SizeClass.compact:
      return const EdgeInsets.symmetric(horizontal: 12);
    case _SizeClass.medium:
      return const EdgeInsets.symmetric(horizontal: 20);
    case _SizeClass.expanded:
      return const EdgeInsets.symmetric(horizontal: 24);
  }
}

/// ---------- Screen ----------
class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key, required this.userId});

  /// Convenience factory if you use named routes with args
  static Widget fromRoute(BuildContext context, Object? args) {
    String? userId;
    if (args is Map) userId = args['userId'] as String?;
    return ProfileViewScreen(userId: userId ?? '');
  }

  final String userId;

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final _peopleRepo = PeopleRepo();
  final _socialRepo = SocialRepo();
  final _chatRepo = ChatRepo();

  late Future<Person?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Person?> _load() async {
    if (widget.userId.isEmpty) return null;
    return _peopleRepo.getById(widget.userId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  bool get _isSelf => supa.auth.currentUser?.id == widget.userId;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final clamped = media.copyWith(
      // keep a11y but avoid extreme blow-ups
      textScaler: media.textScaler.clamp(maxScaleFactor: 1.2),
    );

    return MediaQuery(
      data: clamped,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sc = _classOf(constraints);
          final expandedHeight = switch (sc) {
            _SizeClass.compact => 220.0,
            _SizeClass.medium => 280.0,
            _SizeClass.expanded => 320.0,
          };

          return Scaffold(
            body: FutureBuilder<Person?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  final theme = Theme.of(context);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load profile.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final person = snap.data;
                if (person == null) {
                  final theme = Theme.of(context);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_off_outlined, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'User not found',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Go back'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    slivers: [
                      _HeaderSliver(
                        person: person,
                        isSelf: _isSelf,
                        expandedHeight: expandedHeight,
                      ),
                      // Identity card BELOW the header (no overlay on image)
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc).copyWith(top: 12, bottom: 8),
                              child: _IdentityCard(person: person),
                            ),
                          ),
                        ),
                      ),
                      // Actions row (and quick details side-by-side on wide screens)
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc).copyWith(bottom: 8),
                              child: _ResponsiveBody(
                                sizeClass: sc,
                                person: person,
                                isSelf: _isSelf,
                                socialRepo: _socialRepo,
                                chatRepo: _chatRepo,
                                onChanged: _refresh,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Stats
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc).copyWith(bottom: 8),
                              child: _StatsStrip(userId: person.userId),
                            ),
                          ),
                        ),
                      ),
                      // Details card
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc).copyWith(bottom: 8),
                              child: _DetailsCard(person: person),
                            ),
                          ),
                        ),
                      ),
                      // Moments button
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc),
                              child: _MomentsButton(userId: person.userId),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Header shows ONLY cover image (no avatar/name/gender/location on top)
class _HeaderSliver extends StatelessWidget {
  const _HeaderSliver({
    required this.person,
    required this.isSelf,
    required this.expandedHeight,
  });

  final Person person;
  final bool isSelf;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAvatar =
        (person.avatarUrl != null && person.avatarUrl!.isNotEmpty);

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,

      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.maybePop(context),
      ),
      actions: [
        if (!isSelf)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              HapticFeedback.selectionClick();
              if (v == 'report') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reported (demo)')),
                );
              } else if (v == 'block') {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Blocked (demo)')));
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'report', child: Text('Report user')),
              PopupMenuItem(value: 'block', child: Text('Block user')),
            ],
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: hasAvatar
            ? ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.25),
                  BlendMode.darken,
                ),
                child: Image(
                  image: CachedNetworkImageProvider(person.avatarUrl!),
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Identity card: avatar + name + gender + location (separate from header)
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.person});
  final Person person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    [
      person.subcity,
      person.city,
      person.region,
      person.country,
    ].where((e) => (e ?? '').trim().isNotEmpty).cast<String>().toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 16),
            // Name + gender + location
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveBody extends StatelessWidget {
  const _ResponsiveBody({
    required this.sizeClass,
    required this.person,
    required this.isSelf,
    required this.socialRepo,
    required this.chatRepo,
    required this.onChanged,
  });

  final _SizeClass sizeClass;
  final Person person;
  final bool isSelf;
  final SocialRepo socialRepo;
  final ChatRepo chatRepo;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final isTwoCol = sizeClass != _SizeClass.compact;

    if (!isTwoCol) {
      // Single column (phones)
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoAndActions(
            person: person,
            isSelf: isSelf,
            socialRepo: socialRepo,
            chatRepo: chatRepo,
            onChanged: onChanged,
          ),
        ],
      );
    }

    // Two columns (tablets/desktop)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: actions
        Expanded(
          flex: 7,
          child: _InfoAndActions(
            person: person,
            isSelf: isSelf,
            socialRepo: socialRepo,
            chatRepo: chatRepo,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 16),
        // Right column: quick details peek
        Expanded(flex: 6, child: _QuickDetailsPeek(person: person)),
      ],
    );
  }
}

class _QuickDetailsPeek extends StatelessWidget {
  const _QuickDetailsPeek({required this.person});
  final Person person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locParts = [
      person.subcity,
      person.city,
      person.region,
      person.country,
    ].where((e) => (e ?? '').trim().isNotEmpty).cast<String>().toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Gender: ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Flexible(child: Text(person.gender)),
              ],
            ),
            if (locParts.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Location: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      locParts.join(', '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Follow/Message/Call row
class _InfoAndActions extends StatefulWidget {
  const _InfoAndActions({
    required this.person,
    required this.isSelf,
    required this.socialRepo,
    required this.chatRepo,
    required this.onChanged,
  });

  final Person person;
  final bool isSelf;
  final SocialRepo socialRepo;
  final ChatRepo chatRepo;
  final Future<void> Function() onChanged;

  @override
  State<_InfoAndActions> createState() => _InfoAndActionsState();
}

class _InfoAndActionsState extends State<_InfoAndActions> {
  late Future<bool> _followingFuture;

  @override
  void initState() {
    super.initState();
    _followingFuture = widget.socialRepo.isFollowing(widget.person.userId);
  }

  void _refreshFollowing() {
    setState(() {
      _followingFuture = widget.socialRepo.isFollowing(widget.person.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isSelf) {
      // Self profile: Edit & Moments
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MomentsScreen(userId: supa.auth.currentUser!.id),
                  ),
                ),
                icon: const Icon(Icons.burst_mode_outlined),
                label: const Text('My Moments'),
              ),
            ),
          ],
        ),
      );
    }

    // Other user: Follow, Message, Call
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<bool>(
              future: _followingFuture,
              builder: (context, snap) {
                final following = snap.data ?? false;
                return FilledButton.icon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    try {
                      if (following) {
                        await widget.socialRepo.unfollow(widget.person.userId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unfollowed')),
                        );
                      } else {
                        await widget.socialRepo.follow(widget.person.userId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Followed')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Action failed: $e')),
                      );
                    } finally {
                      _refreshFollowing();
                      await widget.onChanged();
                    }
                  },
                  icon: Icon(
                    following
                        ? Icons.check_rounded
                        : Icons.person_add_alt_1_rounded,
                  ),
                  label: Text(following ? 'Following' : 'Follow'),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final convId = await widget.chatRepo.upsertDirectConversation(
                  widget.person.userId,
                );
                if (context.mounted) {
                  context.push('/chat/$convId');
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message'),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Call',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(peerId: widget.person.userId),
                ),
              );
            },
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
      ),
    );
  }
}

/// Followers • Following • Likes
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = SocialRepo();

    Widget stat(String label, Stream<int> stream, VoidCallback? onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: StreamBuilder<int>(
              stream: stream,
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: theme.textTheme.bodySmall),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          stat('Followers', repo.followersCount(userId), () {
            Navigator.pushNamed(
              context,
              '/follow/list',
              arguments: {'userId': userId, 'showFollowers': true},
            );
          }),
          _divider(theme),
          stat('Following', repo.followingCount(userId), () {
            Navigator.pushNamed(
              context,
              '/follow/list',
              arguments: {'userId': userId, 'showFollowers': false},
            );
          }),
          _divider(theme),
          stat('Likes', repo.likesReceivedCount(userId), null),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) => Container(
    width: 1,
    height: 40,
    color: theme.dividerColor.withOpacity(.3),
  );
}

/// Details card (gender + location again in a full section)
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.person});
  final Person person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locParts = [
      person.subcity,
      person.city,
      person.region,
      person.country,
    ].where((e) => (e ?? '').trim().isNotEmpty).cast<String>().toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Gender'),
            subtitle: Text(person.gender),
          ),
          if (locParts.isNotEmpty) const Divider(height: 1),
          if (locParts.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Location'),
              subtitle: Text(locParts.join(', ')),
            ),
        ],
      ),
    );
  }
}

class _MomentsButton extends StatelessWidget {
  const _MomentsButton({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.burst_mode_outlined),
        label: const Text('View Moments'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MomentsScreen(userId: userId)),
        ),
      ),
    );
  }
}
