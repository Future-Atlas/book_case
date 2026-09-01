import '../models/post.dart';

class TimelineRankingService {
  const TimelineRankingService._();

  static List<Post> arrange({
    required Iterable<Post> posts,
    required Set<String> followedProfileIds,
  }) {
    final followedPosts = <Post>[];
    final popularPosts = <Post>[];
    final seenPostIds = <String>{};

    for (final post in posts) {
      if (!seenPostIds.add(post.id)) continue;
      if (followedProfileIds.contains(post.profileId)) {
        followedPosts.add(post);
      } else {
        popularPosts.add(post);
      }
    }

    followedPosts.sort(_compareByPopularity);
    popularPosts.sort(_compareByPopularity);

    if (followedPosts.isEmpty) return popularPosts;
    if (popularPosts.isEmpty) return followedPosts;

    final arranged = <Post>[];
    final maxLength = followedPosts.length > popularPosts.length
        ? followedPosts.length
        : popularPosts.length;
    for (var index = 0; index < maxLength; index++) {
      if (index < followedPosts.length) arranged.add(followedPosts[index]);
      if (index < popularPosts.length) arranged.add(popularPosts[index]);
    }
    return arranged;
  }

  static int _compareByPopularity(Post first, Post second) {
    final scoreComparison = second.reactionScore.compareTo(first.reactionScore);
    if (scoreComparison != 0) return scoreComparison;
    return second.createdAt.compareTo(first.createdAt);
  }
}
