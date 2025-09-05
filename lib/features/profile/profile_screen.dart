import 'package:chating_app/features/coins/gifts_screen.dart';
import 'package:chating_app/features/coins/wallet_screen.dart';
import 'package:chating_app/features/users/users_payment_status_list.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supa.dart';
import 'profile_repo.dart';
import 'profile_model.dart';
import 'profile_button.dart' show showProfilePopup;
import '../social/social_repo.dart';
import '../social/follow_list_screen.dart';
import '../moments/moments_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final repo = ProfileRepo();
  final _picker = ImagePicker();

  Profile? me;
  bool _busy = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _load();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await repo.getMe();
    if (!mounted) return;
    setState(() {
      me = p;
    });
  }

  Future<void> _onChangeAvatar() async {
    if (me == null) return;
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, _AvatarAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, _AvatarAction.gallery),
            ),
            if (((me!.avatarUrl) ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
              ),
            SizedBox(height: MediaQuery.of(ctx).size.width * 0.02),
          ],
        ),
      ),
    );

    if (action == null) return;

    switch (action) {
      case _AvatarAction.camera:
        await _pickAndUpload(ImageSource.camera);
        break;
      case _AvatarAction.gallery:
        await _pickAndUpload(ImageSource.gallery);
        break;
      case _AvatarAction.remove:
        await _removeAvatar();
        break;
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (me == null) return;
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (xfile == null) return;

      setState(() => _busy = true);

      final userId = supa.auth.currentUser!.id;
      final ext = p.extension(xfile.name).ifEmpty('.jpg');
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}$ext';
      final bytes = await xfile.readAsBytes();

      final mime = lookupMimeType(xfile.path) ?? 'image/jpeg';

      final storage = supa.storage.from('avatars');
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );

      final publicUrl = storage.getPublicUrl(path);

      await _updateAvatarUrl(publicUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avatar updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Avatar update failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (me == null) return;
    try {
      setState(() => _busy = true);
      await _updateAvatarUrl(null);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avatar removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove avatar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateAvatarUrl(String? url) async {
    final userId = supa.auth.currentUser!.id;
    await supa
        .from('profiles')
        .update({'avatar_url': url})
        .eq('user_id', userId);
    await _load();
  }

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isAdmin = me?.role == 'admin';

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: theme.colorScheme.background,
            elevation: 3,
            shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  size: screenWidth * 0.06,
                  color: theme.colorScheme.onSurface,
                ),
                tooltip: 'Settings',
                onPressed: () => showProfilePopup(context),
              ),
            ],
          ),
          body: me == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = screenWidth * 0.04;
                    return ListView(
                      padding: EdgeInsets.all(padding),
                      children: [
                        // Header: avatar + gender icon + name + verified icon
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _EditableAvatar(
                                url: me!.avatarUrl,
                                fallback: me!.displayName,
                                onEdit: _onChangeAvatar,
                                busy: _busy,
                                screenWidth: screenWidth,
                              ),
                              SizedBox(width: padding),
                              Expanded(
                                child: Row(
                                  children: [
                                    Semantics(
                                      label: _getGenderLabel(me!.gender),
                                      child: Icon(
                                        _getGenderIcon(me!.gender),
                                        size: screenWidth * 0.06,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.9),
                                      ),
                                    ),
                                    SizedBox(width: padding * 0.5),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              me!.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize:
                                                        screenWidth * 0.05,
                                                  ),
                                            ),
                                          ),
                                          if (me!.toJson()['is_verified_gender'] ==
                                              true)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                left: screenWidth * 0.02,
                                              ),
                                              child: Icon(
                                                Icons.verified,
                                                size: screenWidth * 0.05,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: padding * 2),

                        // Stats: Followers • Following • Likes
                        _ProfileStatsRow(
                          userId: supa.auth.currentUser!.id,
                          screenWidth: screenWidth,
                        ),

                        SizedBox(height: padding * 2),

                        // Info + Moments
                        Card(
                          elevation: 6,
                          shadowColor: theme.colorScheme.shadow.withOpacity(
                            0.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(
                                  Icons.burst_mode_outlined,
                                  size: screenWidth * 0.045,
                                ),
                                title: Text(
                                  'View Moments',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  size: screenWidth * 0.045,
                                ),
                                onTap: () {
                                  final uid = supa.auth.currentUser!.id;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MomentsScreen(userId: uid),
                                    ),
                                  );
                                },
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: padding,
                                endIndent: padding,
                              ),
                              ListTile(
                                leading: Icon(
                                  Icons.currency_exchange_outlined,
                                  size: screenWidth * 0.045,
                                ),
                                title: Text(
                                  'Coins',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  size: screenWidth * 0.045,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WalletScreen(),
                                    ),
                                  );
                                },
                              ),
                               Divider(
                                height: 1,
                                thickness: 1,
                                indent: padding,
                                endIndent: padding,
                              ),
                              ListTile(
                                leading: Icon(
                                  Icons.wallet_giftcard_outlined,
                                  size: screenWidth * 0.045,
                                ),
                                title: Text(
                                  'Gifts',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  size: screenWidth * 0.045,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GiftsScreen(),
                                    ),
                                  );
                                },
                              ),
                              if (isAdmin)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: padding,
                                  endIndent: padding,
                                ),
                              if (isAdmin)
                                ListTile(
                                  leading: Icon(
                                    Icons.people_outline,
                                    size: screenWidth * 0.045,
                                  ),
                                  title: Text(
                                    'Users',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    size: screenWidth * 0.045,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const UsersPurchaseStatus(),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),

                        SizedBox(height: padding * 2),

                        // Edit profile
                        SizedBox(
                          width: double.infinity,
                          child: _AnimatedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/profile/edit'),
                            icon: Icons.edit,
                            label: 'Edit profile',
                            isFilled: true,
                            theme: theme,
                            screenWidth: screenWidth,
                            animationController: _animationController,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),

        if (_busy)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: 0.06,
                duration: const Duration(milliseconds: 150),
                child: Container(color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.url,
    required this.fallback,
    required this.onEdit,
    required this.busy,
    required this.screenWidth,
  });

  final String? url;
  final String fallback;
  final VoidCallback onEdit;
  final bool busy;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = (fallback.isNotEmpty ? fallback[0] : 'U').toUpperCase();
    final hasUrl = (url ?? '').isNotEmpty;
    final avatarSize = screenWidth * 0.1;

    final avatar = CircleAvatar(
      radius: avatarSize,
      backgroundImage: hasUrl ? CachedNetworkImageProvider(url!) : null,
      backgroundColor: hasUrl ? null : theme.colorScheme.primary,
      child: hasUrl
          ? null
          : Text(
              letter,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: avatarSize * 0.5,
              ),
            ),
    );

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Semantics(label: 'Profile avatar', child: avatar),
        Positioned(
          right: -4,
          bottom: -4,
          child: Tooltip(
            message: 'Change avatar',
            child: InkWell(
              onTap: busy ? null : onEdit,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: avatarSize * 0.3,
                backgroundColor: theme.colorScheme.primary,
                child: busy
                    ? SizedBox(
                        height: avatarSize * 0.2,
                        width: avatarSize * 0.2,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.edit,
                        size: avatarSize * 0.3,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.userId, required this.screenWidth});

  final String userId;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = SocialRepo();

    return Card(
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.03,
          horizontal: screenWidth * 0.02,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatTile(
              label: 'Followers',
              stream: repo.followersCount(userId),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FollowListScreen(userId: userId, showFollowers: true),
                ),
              ),
              screenWidth: screenWidth,
            ),
            _DividerLine(screenWidth: screenWidth),
            _StatTile(
              label: 'Following',
              stream: repo.followingCount(userId),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FollowListScreen(userId: userId, showFollowers: false),
                ),
              ),
              screenWidth: screenWidth,
            ),
            _DividerLine(screenWidth: screenWidth),
            _StatTile(
              label: 'Likes',
              stream: repo.likesReceivedCount(userId),
              onTap: null,
              screenWidth: screenWidth,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.stream,
    required this.screenWidth,
    this.onTap,
  });

  final String label;
  final Stream<int> stream;
  final VoidCallback? onTap;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.015,
          vertical: screenWidth * 0.02,
        ),
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
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine({required this.screenWidth});

  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: screenWidth * 0.06,
      color: theme.dividerColor.withOpacity(0.4),
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
          CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
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

enum _AvatarAction { camera, gallery, remove }

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}