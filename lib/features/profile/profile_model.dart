// profile_model.dart
class Profile {
  final String userId;
  final String displayName;
  final String gender;
  final String? avatarUrl;
  final bool isVerifiedGender;
  final String? role; // 👈

  Profile({
    required this.userId,
    required this.displayName,
    required this.gender,
    required this.role,
    this.avatarUrl,
    this.isVerifiedGender = false,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
        gender: j['gender'] as String,
        avatarUrl: j['avatar_url'] as String?,
        role:j["role"] as String?,
        isVerifiedGender: (j['is_verified_gender'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'gender': gender,
        'avatar_url': avatarUrl,
        'is_verified_gender': isVerifiedGender,
      };
}
