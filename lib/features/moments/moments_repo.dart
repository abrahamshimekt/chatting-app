import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supa.dart';
import 'moment_model.dart';

class MomentsRepo {
  final SupabaseClient _c = supa;

  /// Live feed of a single user's moments (newest first).
  Stream<List<Moment>> myMoments(String userId) {
    return _c
        .from('moments')
        .stream(primaryKey: ['id'])
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((e) => Moment.fromJson(e as Map<String, dynamic>)).toList());
  }

  /// Uploads an image/video to the `moments` bucket and returns a public URL.
  Future<String?> _uploadMedia(File file, {required String authorId}) async {
    final ext = p.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.mov', '.m4v', '.webm'].contains(ext);
    final folder = isVideo ? 'videos' : 'images';
    final path = '$authorId/$folder/${DateTime.now().millisecondsSinceEpoch}$ext';

    await _c.storage.from('moments').upload(path, file);
    // If bucket is public:
    return _c.storage.from('moments').getPublicUrl(path);

    // If bucket is private, use signed URLs instead:
    // final signed = await _c.storage.from('moments').createSignedUrl(path, 60 * 60 * 24 * 7);
    // return signed;
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
    required String id,      // UUID
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

  Future<void> deleteMoment(String id) async {
    await _c.from('moments').delete().eq('id', id);
  }

  /// Create using a direct URL (for your CreateMomentScreen)
  Future<void> create({
    required String mediaUrl,
    required String mediaType, // 'image' or 'video'
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
}
