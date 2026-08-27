import 'package:flutter_application_1/models/post.dart';
import 'package:flutter_application_1/models/social_models.dart';
import 'package:flutter_application_1/services/timeline_ranking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('followed and popular posts alternate starting with followed', () {
    final arranged = TimelineRankingService.arrange(
      posts: [
        _post('popular-low', 'other-1', likes: 1),
        _post('follow-low', 'followed-1', likes: 2),
        _post('popular-high', 'other-2', likes: 8),
        _post('follow-high', 'followed-2', loves: 5),
        _post('popular-mid', 'other-3', likes: 4),
      ],
      followedProfileIds: const {'followed-1', 'followed-2'},
    );

    expect(arranged.map((post) => post.id), [
      'follow-high',
      'popular-high',
      'follow-low',
      'popular-mid',
      'popular-low',
    ]);
  });

  test('popular posts remain score ordered when there are no follows', () {
    final arranged = TimelineRankingService.arrange(
      posts: [
        _post('low', 'other-1', likes: 1),
        _post('high', 'other-2', loves: 2),
      ],
      followedProfileIds: const {},
    );

    expect(arranged.map((post) => post.id), ['high', 'low']);
  });
}

Post _post(
  String id,
  String profileId, {
  int likes = 0,
  int loves = 0,
  int sad = 0,
}) {
  return Post(
    id: id,
    profileId: profileId,
    bookId: 'book-$id',
    rating: 4,
    comment: 'review',
    createdAt: DateTime.utc(2026, 8, 27),
    username: profileId,
    userAvatarUrl: '',
    bookTitle: id,
    bookAuthor: 'author',
    bookCoverUrl: '',
    reactionCounts: {
      PostReactionType.like: likes,
      PostReactionType.love: loves,
      PostReactionType.sad: sad,
    },
  );
}
