import '../../core/supa.dart';

class SocialRepo {
  final _c = supa;

  /// Follow / Unfollow
  Future<void> follow(String followeeId) async {
    final me = _c.auth.currentUser!.id;
    await _c.from('follows').insert({
      'follower_id': me,
      'followee_id': followeeId,
    });
  }

  Future<void> unfollow(String followeeId) async {
    final me = _c.auth.currentUser!.id;
    await _c
        .from('follows')
        .delete()
        .eq('follower_id', me)
        .eq('followee_id', followeeId);
  }

  Future<bool> isFollowing(String followeeId) async {
    final me = _c.auth.currentUser!.id;
    final row = await _c
        .from('follows')
        .select('follower_id')
        .eq('follower_id', me)
        .eq('followee_id', followeeId)
        .maybeSingle();
    return row != null;
  }

  /// Counts (realtime)
  Stream<int> followersCount(String userId) => _c
      .from('follows')
      .stream(primaryKey: ['follower_id', 'followee_id'])
      .eq('followee_id', userId)
      .map((rows) => rows.length);

  Stream<int> followingCount(String userId) => _c
      .from('follows')
      .stream(primaryKey: ['follower_id', 'followee_id'])
      .eq('follower_id', userId)
      .map((rows) => rows.length);

  /// Likes received = likes on my moments (realtime)
  Stream<int> likesReceivedCount(String userId) async* {
    // Get this user's moment IDs once (you can convert this to a stream if needed)
    final myMomentsRes =
        await _c.from('moments').select('id').eq('author_id', userId);
    final myMomentList = (myMomentsRes as List)
        .map((e) => (e as Map<String, dynamic>)['id'] as int)
        .toSet();

    yield* _c
        .from('moment_likes')
        .stream(primaryKey: ['user_id', 'moment_id'])
        .map((rows) => rows
            .where((r) => myMomentList.contains(r['moment_id'] as int))
            .length);
  }

  /// Helpers
  String _inUuidList(List<String> ids) =>
      '(${ids.map((e) => '"$e"').join(',')})';

  /// Followers list (profiles of people who follow userId)
  Stream<List<Map<String, dynamic>>> followers(String userId) {
    return _c
        .from('follows')
        .stream(primaryKey: ['follower_id', 'followee_id'])
        .eq('followee_id', userId)
        .map((rows) =>
            rows.map((r) => r['follower_id'] as String).toList(growable: false))
        .asyncMap((ids) async {
          if (ids.isEmpty) return <Map<String, dynamic>>[];
          final res = await _c
              .from('profiles')
              .select('user_id, display_name, gender, avatar_url')
              // fallback when `.in_()` not available:
              .filter('user_id', 'in', _inUuidList(ids));
          return List<Map<String, dynamic>>.from(res as List);
        });
  }

  /// Following list (profiles of people that userId is following)
  Stream<List<Map<String, dynamic>>> following(String userId) {
    return _c
        .from('follows')
        .stream(primaryKey: ['follower_id', 'followee_id'])
        .eq('follower_id', userId)
        .map((rows) =>
            rows.map((r) => r['followee_id'] as String).toList(growable: false))
        .asyncMap((ids) async {
          if (ids.isEmpty) return <Map<String, dynamic>>[];
          final res = await _c
              .from('profiles')
              .select('user_id, display_name, gender, avatar_url')
              .filter('user_id', 'in', _inUuidList(ids));
          return List<Map<String, dynamic>>.from(res as List);
        });
  }
}
