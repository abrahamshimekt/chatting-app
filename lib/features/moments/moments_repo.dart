import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supa.dart';
import 'moment_model.dart';

class MomentsRepo {
  final SupabaseClient _c = supa;

  /// Live feed of a single user's moments (newest first), including likes and viewers count.
  Stream<List<Moment>> myMoments(String userId) {
    return _c
        .from('moments')
        .stream(primaryKey: ['id'])
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .map((rows) async {
          final moments = rows.map((e) => Moment.fromJson(e)).toList();
          // Fetch likes and viewers count for each moment
          for (var i = 0; i < moments.length; i++) {
            final likesCount = await getLikesCount(moments[i].id);
            final viewersCount = await getViewersCount(moments[i].id);
            moments[i] = Moment(
              id: moments[i].id,
              authorId: moments[i].authorId,
              text: moments[i].text,
              mediaType: moments[i].mediaType,
              mediaUrl: moments[i].mediaUrl,
              createdAt: moments[i].createdAt,
              updatedAt: moments[i].updatedAt,
              likesCount: likesCount,
              viewersCount: viewersCount,
              comments: moments[i].comments,
            );
          }
          return moments;
        })
        .asyncMap((future) => future);
  }

  /// Uploads an image/video to the `moments` bucket and returns a public URL.
  Future<String?> _uploadMedia(File file, {required String authorId}) async {
    final ext = p.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.mov', '.m4v', '.webm'].contains(ext);
    final folder = isVideo ? 'videos' : 'images';
    final path = '$authorId/$folder/${DateTime.now().millisecondsSinceEpoch}$ext';

    await _c.storage.from('moments').upload(path, file);
    return _c.storage.from('moments').getPublicUrl(path);
  }

  /// Create from picker (optional text + optional media file)
  Future<void> createMoment({
    required String authorId,
    String? text,
    File? media,
  }) async {
    String mediaType = 'none';
    String? mediaUrl;

    if (media != null) {
      final url = await _uploadMedia(media, authorId: authorId);
      mediaUrl = url;
      final ext = p.extension(media.path).toLowerCase();
      mediaType = ['.mp4', '.mov', '.m4v', '.webm'].contains(ext) ? 'video' : 'image';
    }

    await _c.from('moments').insert({
      'author_id': authorId,
      'text': (text?.trim().isEmpty ?? true) ? null : text!.trim(),
      'media_type': mediaType,
      'media_url': mediaUrl,
    });
  }

  /// Update (optionally swap media)
  Future<void> updateMoment({
    required String id,
    String? text,
    File? newMedia,
    required String authorId,
  }) async {
    String? mediaUrl;
    String? mediaType;

    if (newMedia != null) {
      mediaUrl = await _uploadMedia(newMedia, authorId: authorId);
      final ext = p.extension(newMedia.path).toLowerCase();
      mediaType = ['.mp4', '.mov', '.m4v', '.webm'].contains(ext) ? 'video' : 'image';
    }

    final update = <String, dynamic>{};
    if (text != null) update['text'] = text.trim().isEmpty ? null : text.trim();
    if (mediaUrl != null) {
      update['media_url'] = mediaUrl;
      update['media_type'] = mediaType;
    }
    if (update.isEmpty) return;

    await _c.from('moments').update(update).eq('id', id);
  }

  /// Delete a moment
  Future<void> deleteMoment(String id) async {
    await _c.from('moments').delete().eq('id', id);
  }

  /// Create using a direct URL (for CreateMomentScreen)
  Future<void> create({
    required String mediaUrl,
    required String mediaType,
    String? caption,
  }) async {
    final me = _c.auth.currentUser!.id;
    await _c.from('moments').insert({
      'author_id': me,
      'text': (caption?.trim().isEmpty ?? true) ? null : caption!.trim(),
      'media_type': mediaType,
      'media_url': mediaUrl.trim(),
    });
  }

  /// Like a moment
  Future<void> likeMoment(String momentId, String userId) async {
    await _c.from('moment_likes').insert({
      'moment_id': momentId,
      'user_id': userId,
    });
  }

  /// Unlike a moment
  Future<void> unlikeMoment(String momentId, String userId) async {
    await _c.from('moment_likes').delete().eq('moment_id', momentId).eq('user_id', userId);
  }

  /// Get the number of likes for a moment
  Future<int> getLikesCount(String momentId) async {
    final response = await _c.from('moment_likes').select().eq('moment_id', momentId).count();
    return response.count;
  }

  /// Check if the current user has liked a moment
  Future<bool> hasLiked(String momentId, String userId) async {
    final response = await _c
        .from('moment_likes')
        .select()
        .eq('moment_id', momentId)
        .eq('user_id', userId)
        .maybeSingle();
    return response != null;
  }

  /// Create a comment
  Future<void> createComment({
    required String momentId,
    required String authorId,
    required String body,
    String lang = 'en',
  }) async {
    await _c.from('moment_comments').insert({
      'moment_id': momentId,
      'author_id': authorId,
      'body': body.trim(),
      'lang': lang,
    });
  }

  /// Get comments for a moment
  Stream<List<MomentComment>> getComments(String momentId) {
    return _c
        .from('moment_comments')
        .stream(primaryKey: ['id'])
        .eq('moment_id', momentId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((e) => MomentComment.fromJson(e)).toList());
  }

  /// Increment view count (placeholder: assumes moment_views table or counter)
  Future<void> incrementViewCount(String momentId, String userId) async {
    // Placeholder: Update this if moment_views table is created
    try {
      await _c.from('moment_views').insert({
        'moment_id': momentId,
        'user_id': userId,
      });
    } catch (e) {
      // Ignore duplicate key errors (user already viewed)
      if (e.toString().contains('duplicate key')) return;
      // Fallback: Increment a counter in moments table (requires schema change)
      await _c.rpc('increment_views', params: {'moment_id': momentId});
    }
  }

  /// Get the number of viewers for a moment (placeholder)
  Future<int> getViewersCount(String momentId) async {
    try {
      final response = await _c.from('moment_views').select().eq('moment_id', momentId).count();
      return response.count;
    } catch (e) {
      // Fallback: Return 0 if moment_views table doesn't exist
      return 0;
    }
  }
}