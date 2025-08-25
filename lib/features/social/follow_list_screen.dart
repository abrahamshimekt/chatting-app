import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'social_repo.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final bool showFollowers; // true = Followers, false = Following
  const FollowListScreen({super.key, required this.userId, required this.showFollowers});

  @override
  Widget build(BuildContext context) {
    final repo = SocialRepo();
    final stream = showFollowers ? repo.followers(userId) : repo.following(userId);
    final title = showFollowers ? 'Followers' : 'Following';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return Center(child: Text('No $title.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              final name = (r['display_name'] as String?) ?? 'User';
              final avatarUrl = r['avatar_url'] as String?;
              final avatar = (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? CircleAvatar(radius: 22, backgroundImage: CachedNetworkImageProvider(avatarUrl))
                  : CircleAvatar(radius: 22, child: Text(name[0].toUpperCase()));

              return Card(
                child: ListTile(
                  leading: avatar,
                  title: Text(name),
                  subtitle: Text((r['gender'] ?? '').toString()),
                  onTap: () {
                    Navigator.pushNamed(context, '/profile/view', arguments: {'userId': r['user_id']});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
