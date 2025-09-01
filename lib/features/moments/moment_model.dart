class Moment {
  final String id;           // UUID
  final String authorId;     // UUID
  final String? text;
  final String mediaType;    // 'none'|'image'|'video'
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? likesCount;     // Number of likes
  final int? viewersCount;   // Number of views
  final List<MomentComment>? comments; // List of comments

  Moment({
    required this.id,
    required this.authorId,
    this.text,
    required this.mediaType,
    this.mediaUrl,
    required this.createdAt,
    required this.updatedAt,
    this.likesCount,
    this.viewersCount,
    this.comments,
  });

  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
        id: j['id'] as String,
        authorId: j['author_id'] as String,
        text: j['text'] as String?,
        mediaType: j['media_type'] as String,
        mediaUrl: j['media_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        likesCount: j['likes_count'] as int?,
        viewersCount: j['viewers_count'] as int?,
        comments: j['comments'] != null
            ? (j['comments'] as List).map((e) => MomentComment.fromJson(e)).toList()
            : null,
      );
}

class MomentComment {
  final String id;
  final String momentId;
  final String authorId;
  final String body;
  final String lang;
  final DateTime createdAt;
  final DateTime updatedAt;

  MomentComment({
    required this.id,
    required this.momentId,
    required this.authorId,
    required this.body,
    required this.lang,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MomentComment.fromJson(Map<String, dynamic> j) => MomentComment(
        id: j['id'] as String,
        momentId: j['moment_id'] as String,
        authorId: j['author_id'] as String,
        body: j['body'] as String,
        lang: j['lang'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}