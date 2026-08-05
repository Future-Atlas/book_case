import 'social_models.dart';

class Post {
  final String id;
  final String profileId;
  final String bookId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  // Joined fields
  final String username;
  final String userAvatarUrl;
  final String bookTitle;
  final String bookAuthor;
  final String bookCoverUrl;
  final bool isAgeRestricted;
  final Map<PostReactionType, int> reactionCounts;
  final PostReactionType? currentUserReaction;

  int get reactionsCount => reactionCounts.values.fold(0, (a, b) => a + b);
  bool get reactedByCurrentUser => currentUserReaction != null;

  Post({
    required this.id,
    required this.profileId,
    required this.bookId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.username,
    required this.userAvatarUrl,
    required this.bookTitle,
    required this.bookAuthor,
    required this.bookCoverUrl,
    this.isAgeRestricted = false,
    this.reactionCounts = const {},
    this.currentUserReaction,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    // Handle nesting structures that come back from Supabase join queries (e.g. select: '*,profiles(*),books(*)')
    final profile = json['profiles'] as Map<String, dynamic>?;
    final book = json['books'] as Map<String, dynamic>?;

    return Post(
      id: json['id'] ?? '',
      profileId: json['profile_id'] ?? '',
      bookId: json['book_id'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      username: profile?['username'] ?? '匿名ユーザー',
      userAvatarUrl: profile?['avatar_url'] ?? '',
      bookTitle: json['book_title'] ?? book?['title'] ?? '',
      bookAuthor: json['book_author'] ?? book?['author'] ?? '',
      bookCoverUrl: book?['cover_url'] ?? '',
      isAgeRestricted: json['is_age_restricted'] == true,
      reactionCounts: const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'book_id': bookId,
      'rating': rating,
      'comment': comment,
      'book_title': bookTitle,
      'book_author': bookAuthor,
      'is_age_restricted': isAgeRestricted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Post copyWith({
    String? id,
    String? profileId,
    String? bookId,
    double? rating,
    String? comment,
    DateTime? createdAt,
    String? username,
    String? userAvatarUrl,
    String? bookTitle,
    String? bookAuthor,
    String? bookCoverUrl,
    bool? isAgeRestricted,
    Map<PostReactionType, int>? reactionCounts,
    PostReactionType? currentUserReaction,
  }) {
    return Post(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      bookId: bookId ?? this.bookId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      bookCoverUrl: bookCoverUrl ?? this.bookCoverUrl,
      isAgeRestricted: isAgeRestricted ?? this.isAgeRestricted,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      currentUserReaction: currentUserReaction ?? this.currentUserReaction,
    );
  }
}
