class PostReply {
  final String id;
  final String postId;
  final String profileId;
  final String message;
  final DateTime createdAt;
  final String username;
  final String userAvatarUrl;

  const PostReply({
    required this.id,
    required this.postId,
    required this.profileId,
    required this.message,
    required this.createdAt,
    required this.username,
    required this.userAvatarUrl,
  });

  factory PostReply.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return PostReply(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      username: profile?['username']?.toString() ?? 'ユーザー',
      userAvatarUrl: profile?['avatar_url']?.toString() ?? '',
    );
  }
}