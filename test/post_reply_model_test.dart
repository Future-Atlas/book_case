import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/post_reply.dart';

void main() {
  test('PostReply parses profile identity and parent reply', () {
    final reply = PostReply.fromJson({
      'id': 42,
      'post_id': 'post-id',
      'profile_id': 'profile-id',
      'parent_reply_id': 12,
      'message': '返信本文',
      'created_at': '2026-08-24T06:00:00Z',
      'profiles': {
        'username': '読書好き',
        'user_id': 'reader_42',
        'avatar_url': 'https://example.com/avatar.png',
      },
    });

    expect(reply.id, '42');
    expect(reply.parentReplyId, '12');
    expect(reply.username, '読書好き');
    expect(reply.userId, 'reader_42');
    expect(reply.userAvatarUrl, 'https://example.com/avatar.png');
  });
}
