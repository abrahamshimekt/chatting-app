class Moment {
  final String id;           // UUID
  final String authorId;     // UUID
  final String? text;
  final String mediaType;    // 'none'|'image'|'video'
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Moment({
    required this.id,
    required this.authorId,
    this.text,
    required this.mediaType,
    this.mediaUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
        id: j['id'] as String,
        authorId: j['author_id'] as String,
        text: j['text'] as String?,
        mediaType: j['media_type'] as String,
        mediaUrl: j['media_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
