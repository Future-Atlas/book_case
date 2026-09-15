import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sharemarium/models/post.dart';
import 'package:sharemarium/screens/public_post_routes.dart';
import 'package:sharemarium/services/supabase_service.dart';

class _PostsService extends ChangeNotifier implements SupabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Post>> fetchTimelinePosts() async => [
    Post(
      id: '11111111-1111-4111-8111-111111111111',
      profileId: 'reader',
      bookId: 'book',
      rating: 4,
      comment: '秘密の結末',
      isSpoiler: true,
      createdAt: DateTime(2026, 9, 14),
      username: '読者',
      userAvatarUrl: '',
      bookTitle: 'テスト書籍',
      bookAuthor: '著者',
      bookCoverUrl: '',
    ),
  ];
}

void main() {
  testWidgets('index conceals spoilers and opens the selected review URL', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      ChangeNotifierProvider<SupabaseService>(
        create: (_) => _PostsService(),
        child: MaterialApp(
          home: const PublicPostsScreen(),
          onGenerateRoute: (settings) {
            opened = settings.name;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('レビュー詳細')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('『テスト書籍』'), findsOneWidget);
    expect(find.text('秘密の結末'), findsNothing);
    expect(find.textContaining('ネタバレを含む投稿'), findsOneWidget);
    await tester.tap(find.text('『テスト書籍』'));
    await tester.pumpAndSettle();
    expect(opened, '/posts/11111111-1111-4111-8111-111111111111');
  });
  test('post index and review permalinks have Flutter routes', () {
    for (final name in [
      '/posts',
      '/posts?test=1',
      '/posts/11111111-1111-4111-8111-111111111111',
    ]) {
      final route = publicPostRoute(RouteSettings(name: name));
      expect(route, isNotNull);
      expect(route!.settings.name, name);
    }
  });
  test('other paths and malformed post IDs are not post routes', () {
    for (final name in ['/', '/mypage', '/posts/not-a-uuid', '/posts/a/b']) {
      expect(publicPostRoute(RouteSettings(name: name)), isNull);
    }
  });
}
