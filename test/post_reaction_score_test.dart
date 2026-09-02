import 'package:flutter_test/flutter_test.dart';
import 'package:sharemarium/models/post.dart';
import 'package:sharemarium/models/social_models.dart';

void main() {
  test('reaction score uses the configured timeline weights', () {
    final post = Post(
      id: 'post-1',
      profileId: 'profile-1',
      bookId: 'book-1',
      rating: 4,
      comment: 'review',
      createdAt: DateTime.utc(2026, 8, 19),
      username: 'reader',
      userAvatarUrl: '',
      bookTitle: 'Book',
      bookAuthor: 'Author',
      bookCoverUrl: '',
      reactionCounts: const {
        PostReactionType.like: 3,
        PostReactionType.love: 2,
        PostReactionType.sad: 1,
      },
    );

    expect(post.reactionScore, 7.5);
  });

  test('want-to-read optimistic state toggles independently of reactions', () {
    final post = Post(
      id: 'post-2',
      profileId: 'profile-1',
      bookId: 'book-2',
      rating: 5,
      comment: 'review',
      createdAt: DateTime.utc(2026, 9, 2),
      username: 'reader',
      userAvatarUrl: '',
      bookTitle: 'Book',
      bookAuthor: 'Author',
      bookCoverUrl: '',
      reactionCounts: const {PostReactionType.like: 2},
      wantToReadCount: 3,
    );

    final added = post.withToggledWantToRead();
    expect(added.wantedByCurrentUser, isTrue);
    expect(added.wantToReadCount, 4);
    expect(added.reactionCounts[PostReactionType.like], 2);

    final removed = added.withToggledWantToRead();
    expect(removed.wantedByCurrentUser, isFalse);
    expect(removed.wantToReadCount, 3);
  });
}
