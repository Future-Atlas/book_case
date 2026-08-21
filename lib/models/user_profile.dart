class UserProfile {
  final String id;
  final String username;
  final String userId;
  final String avatarUrl;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int readCount;
  final bool isPrivate;

  UserProfile({
    required this.id,
    required this.username,
    required this.userId,
    required this.avatarUrl,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.readCount,
    required this.isPrivate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      userId: json['user_id'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      bio: json['bio'] ?? '',
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      readCount: json['read_count'] ?? 0,
      isPrivate: json['is_private'] ?? false,
    );
  }

  UserProfile copyWith({
    String? username,
    String? userId,
    String? avatarUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? readCount,
    bool? isPrivate,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      readCount: readCount ?? this.readCount,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'user_id': userId,
      'avatar_url': avatarUrl,
      'bio': bio,
      'followers_count': followersCount,
      'following_count': followingCount,
      'read_count': readCount,
      'is_private': isPrivate,
    };
  }
}
