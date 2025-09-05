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

EdgeInsets _hPad(_SizeClass sc, double screenWidth) {
  final basePadding = screenWidth * 0.04;
  switch (sc) {
    case _SizeClass.compact:
      return EdgeInsets.symmetric(horizontal: basePadding);
    case _SizeClass.medium:
      return EdgeInsets.symmetric(horizontal: basePadding * 1.2);
    case _SizeClass.expanded:
      return EdgeInsets.symmetric(horizontal: basePadding * 1.5);
  }
}

/// ---------- Screen ----------
class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key, required this.userId});

  static Widget fromRoute(BuildContext context, Object? args) {
    String? userId;
    if (args is Map) userId = args['userId'] as String?;
    return ProfileViewScreen(userId: userId ?? '');
  }

  final String userId;

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen>
    with SingleTickerProviderStateMixin {
  final _peopleRepo = PeopleRepo();
  final _socialRepo = SocialRepo();
  final _chatRepo = ChatRepo();

  late Future<Person?> _future;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      textScaler: media.textScaler.clamp(maxScaleFactor: 1.2),
    );

    return MediaQuery(
      data: clamped,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sc = _classOf(constraints);
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final expandedHeight = switch (sc) {
            _SizeClass.compact => screenHeight * 0.3,
            _SizeClass.medium => screenHeight * 0.35,
            _SizeClass.expanded => screenHeight * 0.4,
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
                      padding: EdgeInsets.all(screenWidth * 0.06),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: screenWidth * 0.1,
                          ),
                          SizedBox(height: screenWidth * 0.03),
                          Text(
                            'Failed to load profile.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontSize: screenWidth * 0.045,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.04,
                                vertical: screenWidth * 0.03,
                              ),
                              textStyle: TextStyle(fontSize: screenWidth * 0.04),
                            ),
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
                      padding: EdgeInsets.all(screenWidth * 0.06),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: screenWidth * 0.1,
                            color: theme.colorScheme.onSurface,
                          ),
                          SizedBox(height: screenWidth * 0.03),
                          Text(
                            'User not found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: screenWidth * 0.045,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          TextButton.icon(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Go back'),
                            style: TextButton.styleFrom(
                              textStyle: TextStyle(fontSize: screenWidth * 0.04),
                            ),
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
                        screenWidth: screenWidth,
                      ),
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc, screenWidth).copyWith(top: screenWidth * 0.03, bottom: screenWidth * 0.02),
                              child: _IdentityCard(
                                person: person,
                                screenWidth: screenWidth,
                                sizeClass: sc,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc, screenWidth).copyWith(bottom: screenWidth * 0.02),
                              child: _ResponsiveBody(
                                sizeClass: sc,
                                person: person,
                                isSelf: _isSelf,
                                socialRepo: _socialRepo,
                                chatRepo: _chatRepo,
                                onChanged: _refresh,
                                screenWidth: screenWidth,
                                animationController: _animationController,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc, screenWidth).copyWith(bottom: screenWidth * 0.02),
                              child: _StatsStrip(
                                userId: person.userId,
                                screenWidth: screenWidth,
                              ),
                            ),
                          ),
                        ),
                      ),
                     
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _maxContentWidth(sc),
                            ),
                            child: Padding(
                              padding: _hPad(sc, screenWidth),
                              child: _MomentsButton(
                                userId: person.userId,
                                screenWidth: screenWidth,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: screenWidth * 0.06)),
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

/// Header shows ONLY cover image
class _HeaderSliver extends StatelessWidget {
  const _HeaderSliver({
    required this.person,
    required this.isSelf,
    required this.expandedHeight,
    required this.screenWidth,
  });

  final Person person;
  final bool isSelf;
  final double expandedHeight;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAvatar = (person.avatarUrl != null && person.avatarUrl!.isNotEmpty);

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Blocked (demo)')),
                );
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
                  Colors.black.withOpacity(0.3),
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
                      theme.colorScheme.primaryContainer.withOpacity(0.8),
                      theme.colorScheme.secondaryContainer.withOpacity(0.8),
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

/// Identity card: gender icon + name + location (no avatar)
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.person,
    required this.screenWidth,
    required this.sizeClass,
  });

  final Person person;
  final double screenWidth;
  final _SizeClass sizeClass;

  IconData _getGenderIcon(String? gender) {
    switch (gender?.toLowerCase().trim()) {
      case 'male':
        return Icons.male;
      case 'female':
        return Icons.female;
      default:
        return Icons.person;
    }
  }

  String _getGenderLabel(String? gender) {
    switch (gender?.toLowerCase().trim()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLargeScreen = sizeClass != _SizeClass.compact;
    final locParts = [
      person.subcity,
      person.city,
      person.region,
      person.country,
    ].where((e) => (e ?? '').trim().isNotEmpty).cast<String>().toList();

    return Card(
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gender icon + name
            Row(
              children: [
                Semantics(
                  label: _getGenderLabel(person.gender),
                  child: Icon(
                    _getGenderIcon(person.gender),
                    size: isLargeScreen ? 22 : 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: Text(
                    person.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: screenWidth * 0.05,
                    ),
                  ),
                ),
              ],
            ),
            if (locParts.isNotEmpty) ...[
              SizedBox(height: screenWidth * 0.02),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: isLargeScreen ? 18 : 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      locParts.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: screenWidth * 0.035,
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
    required this.screenWidth,
    required this.animationController,
  });

  final _SizeClass sizeClass;
  final Person person;
  final bool isSelf;
  final SocialRepo socialRepo;
  final ChatRepo chatRepo;
  final Future<void> Function() onChanged;
  final double screenWidth;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    final isTwoCol = sizeClass != _SizeClass.compact;

    if (!isTwoCol) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoAndActions(
            person: person,
            isSelf: isSelf,
            socialRepo: socialRepo,
            chatRepo: chatRepo,
            onChanged: onChanged,
            screenWidth: screenWidth,
            animationController: animationController,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: _InfoAndActions(
            person: person,
            isSelf: isSelf,
            socialRepo: socialRepo,
            chatRepo: chatRepo,
            onChanged: onChanged,
            screenWidth: screenWidth,
            animationController: animationController,
          ),
        ),
        SizedBox(width: screenWidth * 0.04),
        Expanded(
          flex: 6,
          child: _QuickDetailsPeek(
            person: person,
            screenWidth: screenWidth,
          ),
        ),
      ],
    );
  }
}

class _QuickDetailsPeek extends StatelessWidget {
  const _QuickDetailsPeek({
    required this.person,
    required this.screenWidth,
  });

  final Person person;
  final double screenWidth;

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
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.03),
        child: Wrap(
          runSpacing: screenWidth * 0.02,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.badge_outlined,
                  color: theme.colorScheme.primary,
                  size: screenWidth * 0.045,
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  'Gender: ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
                Flexible(
                  child: Text(
                    person.gender,
                    style: TextStyle(fontSize: screenWidth * 0.035),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (locParts.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: theme.colorScheme.primary,
                    size: screenWidth * 0.045,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    'Location: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      locParts.join(', '),
                      style: TextStyle(fontSize: screenWidth * 0.035),
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

class _InfoAndActions extends StatefulWidget {
  const _InfoAndActions({
    required this.person,
    required this.isSelf,
    required this.socialRepo,
    required this.chatRepo,
    required this.onChanged,
    required this.screenWidth,
    required this.animationController,
  });

  final Person person;
  final bool isSelf;
  final SocialRepo socialRepo;
  final ChatRepo chatRepo;
  final Future<void> Function() onChanged;
  final double screenWidth;
  final AnimationController animationController;

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
      return Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, widget.screenWidth * 0.02),
        child: Row(
          children: [
            Expanded(
              child: _AnimatedButton(
                onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
                icon: Icons.edit,
                label: 'Edit Profile',
                isFilled: true,
                theme: theme,
                screenWidth: widget.screenWidth,
                animationController: widget.animationController,
              ),
            ),
            SizedBox(width: widget.screenWidth * 0.03),
            Expanded(
              child: _AnimatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MomentsScreen(userId: supa.auth.currentUser!.id),
                  ),
                ),
                icon: Icons.burst_mode_outlined,
                label: 'My Moments',
                isFilled: false,
                theme: theme,
                screenWidth: widget.screenWidth,
                animationController: widget.animationController,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, widget.screenWidth * 0.02),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<bool>(
              future: _followingFuture,
              builder: (context, snap) {
                final following = snap.data ?? false;
                return _AnimatedButton(
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
                  icon: following ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                  label: following ? 'Following' : 'Follow',
                  isFilled: true,
                  theme: theme,
                  screenWidth: widget.screenWidth,
                  animationController: widget.animationController,
                );
              },
            ),
          ),
          SizedBox(width: widget.screenWidth * 0.03),
          Expanded(
            child: _AnimatedButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final convId = await widget.chatRepo.upsertDirectConversation(
                  widget.person.userId,
                );
                if (context.mounted) {
                  context.push('/chat/$convId');
                }
              },
              icon: Icons.chat_bubble_outline,
              label: 'Message',
              isFilled: false,
              theme: theme,
              screenWidth: widget.screenWidth,
              animationController: widget.animationController,
            ),
          ),
          SizedBox(width: widget.screenWidth * 0.03),
          _AnimatedIconButton(
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
            icon: Icons.videocam_outlined,
            theme: theme,
            screenWidth: widget.screenWidth,
            animationController: widget.animationController,
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.userId,
    required this.screenWidth,
  });

  final String userId;
  final double screenWidth;

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
            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
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
                        fontSize: screenWidth * 0.045,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: screenWidth * 0.03,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          stat('Followers', repo.followersCount(userId), () {
            Navigator.pushNamed(
              context,
              '/follow/list',
              arguments: {'userId': userId, 'showFollowers': true},
            );
          }),
          _divider(theme, screenWidth),
          stat('Following', repo.followingCount(userId), () {
            Navigator.pushNamed(
              context,
              '/follow/list',
              arguments: {'userId': userId, 'showFollowers': false},
            );
          }),
          _divider(theme, screenWidth),
          stat('Likes', repo.likesReceivedCount(userId), null),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme, double screenWidth) => Container(
        width: 1,
        height: screenWidth * 0.1,
        color: theme.dividerColor.withOpacity(0.3),
      );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.person,
    required this.screenWidth,
  });

  final Person person;
  final double screenWidth;

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
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.badge_outlined,
              size: screenWidth * 0.045,
            ),
            title: Text(
              'Gender',
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
            subtitle: Text(
              person.gender,
              style: TextStyle(fontSize: screenWidth * 0.035),
            ),
          ),
          if (locParts.isNotEmpty) Divider(height: 1, thickness: 1, indent: screenWidth * 0.04, endIndent: screenWidth * 0.04),
          if (locParts.isNotEmpty)
            ListTile(
              leading: Icon(
                Icons.location_on_outlined,
                size: screenWidth * 0.045,
              ),
              title: Text(
                'Location',
                style: TextStyle(fontSize: screenWidth * 0.04),
              ),
              subtitle: Text(
                locParts.join(', '),
                style: TextStyle(fontSize: screenWidth * 0.035),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _MomentsButton extends StatelessWidget {
  const _MomentsButton({
    required this.userId,
    required this.screenWidth,
  });

  final String userId;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(
          Icons.burst_mode_outlined,
          size: screenWidth * 0.045,
        ),
        label: Text(
          'View Moments',
          style: TextStyle(fontSize: screenWidth * 0.04),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenWidth * 0.03,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MomentsScreen(userId: userId)),
        ),
      ),
    );
  }
}

class _AnimatedButton extends StatelessWidget {
  const _AnimatedButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isFilled,
    required this.theme,
    required this.screenWidth,
    required this.animationController,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isFilled;
  final ThemeData theme;
  final double screenWidth;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        animationController.reset();
        animationController.forward();
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.92).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeInOut,
          ),
        ),
        child: isFilled
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: screenWidth * 0.045),
                label: Text(
                  label,
                  style: TextStyle(fontSize: screenWidth * 0.04),
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenWidth * 0.03,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: screenWidth * 0.045),
                label: Text(
                  label,
                  style: TextStyle(fontSize: screenWidth * 0.04),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenWidth * 0.03,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AnimatedIconButton extends StatelessWidget {
  const _AnimatedIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.theme,
    required this.screenWidth,
    required this.animationController,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final ThemeData theme;
  final double screenWidth;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        animationController.reset();
        animationController.forward();
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.92).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeInOut,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: screenWidth * 0.045,
              color: theme.colorScheme.primary,
            ),
            padding: EdgeInsets.all(screenWidth * 0.03),
            constraints: BoxConstraints.tight(Size(screenWidth * 0.12, screenWidth * 0.12)),
          ),
        ),
      ),
    );
  }
}