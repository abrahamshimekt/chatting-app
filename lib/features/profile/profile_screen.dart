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

class _ProfileScreenState extends State<ProfileScreen> {
  final repo = ProfileRepo();
  final _picker = ImagePicker();

  Profile? me;
  String? email;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await repo.getMe();
    if (!mounted) return;
    setState(() {
      me = p;
      email = supa.auth.currentUser?.email;
    });
  }

  // ---- Avatar editing ----
  Future<void> _onChangeAvatar() async {
    if (me == null) return;
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
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
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
              ),
            const SizedBox(height: 8),
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

      // Ensure you have a bucket named 'avatars'
      final storage = supa.storage.from('avatars');
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );

      // If your bucket is public, use getPublicUrl; if private, generate a signed URL instead.
      final publicUrl = storage.getPublicUrl(path);

      await _updateAvatarUrl(publicUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar update failed: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove avatar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateAvatarUrl(String? url) async {
    final userId = supa.auth.currentUser!.id;
    await supa.from('profiles').update({'avatar_url': url}).eq('user_id', userId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = me?.role == 'admin'; // Assuming role is in Profile model

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => showProfilePopup(context),
              ),
            ],
          ),
          body: me == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ----- Header: avatar + name/email
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _EditableAvatar(
                          url: me!.avatarUrl,
                          fallback: me!.displayName,
                          onEdit: _onChangeAvatar,
                          busy: _busy,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                me!.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ----- Stats: Followers • Following • Likes
                    _ProfileStatsRow(userId: supa.auth.currentUser!.id),

                    const SizedBox(height: 24),

                    // ----- Info + Moments
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.badge_outlined),
                            title: const Text('Gender'),
                            subtitle: Text(me!.gender),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.verified_user_outlined),
                            title: const Text('Gender Verified'),
                            subtitle: Text(
                              me!.toJson()['is_verified_gender'] == true ? 'Yes' : 'No',
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.burst_mode_outlined),
                            title: const Text('View Moments'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final uid = supa.auth.currentUser!.id;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MomentsScreen(userId: uid),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.currency_exchange_outlined),
                            title: const Text('Coins'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WalletScreen(),
                                ),
                              );
                            },
                          ),
                          if (isAdmin)
                            const Divider(height: 1),
                          if (isAdmin)
                            ListTile(
                              leading: const Icon(Icons.people_outline),
                              title: const Text('Users'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UsersPurchaseStatus(),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ----- Edit profile
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit profile'),
                        onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
                      ),
                    ),
                  ],
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

// ====== Small helpers (self-contained) ======

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.url,
    required this.fallback,
    required this.onEdit,
    required this.busy,
  });

  final String? url;
  final String fallback;
  final VoidCallback onEdit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final letter = (fallback.isNotEmpty ? fallback[0] : 'U').toUpperCase();
    final hasUrl = (url ?? '').isNotEmpty;

    final avatar = CircleAvatar(
      radius: 40,
      backgroundImage: hasUrl ? CachedNetworkImageProvider(url!) : null,
      child: hasUrl
          ? null
          : Text(letter, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
    );

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Semantics(
          label: 'Profile avatar',
          child: avatar,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Tooltip(
            message: 'Change avatar',
            child: InkWell(
              onTap: busy ? null : onEdit,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: busy
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final repo = SocialRepo();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatTile(
              label: 'Followers',
              stream: repo.followersCount(userId),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowListScreen(userId: userId, showFollowers: true),
                ),
              ),
            ),
            _DividerLine(),
            _StatTile(
              label: 'Following',
              stream: repo.followingCount(userId),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowListScreen(userId: userId, showFollowers: false),
                ),
              ),
            ),
            _DividerLine(),
            _StatTile(
              label: 'Likes',
              stream: repo.likesReceivedCount(userId),
              onTap: null,
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
    this.onTap,
  });
  final String label;
  final Stream<int> stream;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final textStyle = Theme.of(context).textTheme.labelLarge;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: StreamBuilder<int>(
          stream: stream,
          builder: (context, snap) {
            final count = snap.data ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: textStyle?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Theme.of(context).dividerColor.withOpacity(.4),
    );
  }
}

enum _AvatarAction { camera, gallery, remove }

// Small extension to handle empty extension fallback
extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}