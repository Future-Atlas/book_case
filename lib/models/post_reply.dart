class PostReply {
  final String id;
  final String postId;
  final String profileId;
  final String? parentReplyId;
  final String message;
  final bool hasSpoiler;
  final DateTime createdAt;
  final String username;
  final String userId;
  final String userAvatarUrl;

  const PostReply({
    required this.id,
    required this.postId,
    required this.profileId,
    required this.parentReplyId,
    required this.message,
    required this.hasSpoiler,
    required this.createdAt,
    required this.username,
    required this.userId,
    required this.userAvatarUrl,
  });

  factory PostReply.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return PostReply(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      parentReplyId: json['parent_reply_id']?.toString(),
      message: json['message']?.toString() ?? '',
      hasSpoiler: json['has_spoiler'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      username: profile?['username']?.toString() ?? 'ユーザー',
      userId: profile?['user_id']?.toString() ?? '',
      userAvatarUrl: profile?['avatar_url']?.toString() ?? '',
    );
  }
}
