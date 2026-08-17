import 'package:flutter_application_1/models/book.dart';
import 'package:flutter_application_1/api/rakuten_api.dart';
import 'package:flutter_application_1/repositories/book_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book({
  required String id,
  required String title,
  required String author,
  required String publisher,
  int reviewCount = 0,
  double ratingAvg = 0,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    publisher: publisher,
    pubDate: '',
    isbn: id,
    coverUrl: '',
    reviewCount: reviewCount,
    ratingAvg: ratingAvg,
  );
}

void main() {
  test('楽天検索ではスペースと中点を除いた検索語も生成する', () {
    expect(RakutenApi.buildSearchKeywordVariants('プロジェクト・へイル・メアリー'), [
      'プロジェクト・へイル・メアリー',
      'プロジェクトへイルメアリー',
      'プロジェクト',
    ]);
    expect(RakutenApi.buildSearchKeywordVariants('プロジェクトへイル'), [
      'プロジェクトへイル',
      'プロジェクト',
    ]);
    expect(RakutenApi.buildSearchKeywordVariants('Andy Weir'), [
      'Andy Weir',
      'AndyWeir',
    ]);
  });

  group('検索入力の分類', () {
    test('社で終わる場合は出版社を優先する', () {
      expect(
        BookRepository.searchFieldPriority('講談社').first,
        BookSearchField.publisher,
      );
    });

    test('スペースなし3〜5文字の日本語は著者を優先する', () {
      expect(
        BookRepository.searchFieldPriority('村上春樹').first,
        BookSearchField.author,
      );
    });

    test('カタカナ・カタカナは著者を優先する', () {
      expect(
        BookRepository.searchFieldPriority('アンディ・ウィアー').first,
        BookSearchField.author,
      );
    });

    test('2文字以内と6文字以上はタイトルを優先する', () {
      expect(
        BookRepository.searchFieldPriority('海').first,
        BookSearchField.title,
      );
      expect(
        BookRepository.searchFieldPriority('プロジェクトヘイルメアリー').first,
        BookSearchField.title,
      );
    });

    test('英語の記号入りはタイトルを優先する', () {
      expect(
        BookRepository.searchFieldPriority('What If?').first,
        BookSearchField.title,
      );
    });

    test('英単語2語は著者を優先する', () {
      expect(
        BookRepository.searchFieldPriority('Andy Weir').first,
        BookSearchField.author,
      );
    });

    test('Co.またはcomicsで終わる場合は出版社を優先する', () {
      expect(
        BookRepository.searchFieldPriority('Kodansha Co.').first,
        BookSearchField.publisher,
      );
      expect(
        BookRepository.searchFieldPriority('Marvel Comics').first,
        BookSearchField.publisher,
      );
    });
  });

  test('スペースや中点を除いた完全一致は部分一致より先に並ぶ', () {
    final ranked = BookRepository.rankSearchResults([
      _book(
        id: 'contains',
        title: 'アンディ・ウィアー傑作集',
        author: '別人',
        publisher: '出版社',
        reviewCount: 100,
      ),
      _book(id: 'exact', title: '別の本', author: 'アンディウィアー', publisher: '出版社'),
    ], 'アンディ・ウィアー');

    expect(ranked.first.id, 'exact');
  });

  test('中点の有無が異なるタイトルも完全一致として扱う', () {
    final ranked = BookRepository.rankSearchResults([
      _book(
        id: 'match',
        title: 'プロジェクト・へイル・メアリー',
        author: 'アンディ・ウィアー',
        publisher: '早川書房',
      ),
      _book(
        id: 'partial',
        title: 'プロジェクトへイルメアリー読本',
        author: '別の著者',
        publisher: '別の出版社',
        reviewCount: 100,
      ),
    ], 'プロジェクトへイルメアリー');

    expect(ranked.first.id, 'match');
  });

  test('20冊を優先度1に10冊、優先度2に5冊、優先度3に5冊配分する', () {
    final books = <Book>[
      for (var i = 0; i < 12; i++)
        _book(
          id: 'author-$i',
          title: '別の本$i',
          author: '村上春樹作品$i',
          publisher: '別の出版社',
          reviewCount: 100 - i,
        ),
      for (var i = 0; i < 7; i++)
        _book(
          id: 'title-$i',
          title: '村上春樹を読む$i',
          author: '別の著者$i',
          publisher: '別の出版社',
          reviewCount: 100 - i,
        ),
      for (var i = 0; i < 7; i++)
        _book(
          id: 'publisher-$i',
          title: '別の本$i',
          author: '別の著者$i',
          publisher: '村上春樹出版$i',
          reviewCount: 100 - i,
        ),
    ];

    final ranked = BookRepository.rankSearchResults(books, '村上春樹');

    expect(
      ranked.take(10).every((book) => book.id.startsWith('author-')),
      isTrue,
    );
    expect(
      ranked.skip(10).take(5).every((book) => book.id.startsWith('title-')),
      isTrue,
    );
    expect(
      ranked.skip(15).take(5).every((book) => book.id.startsWith('publisher-')),
      isTrue,
    );
  });

  test('優先度3の候補がない場合は優先度2の残りで4行目を補う', () {
    final books = <Book>[
      for (var i = 0; i < 10; i++)
        _book(
          id: 'author-$i',
          title: '別の本$i',
          author: '村上春樹作品$i',
          publisher: '別の出版社',
        ),
      for (var i = 0; i < 10; i++)
        _book(
          id: 'title-$i',
          title: '村上春樹を読む$i',
          author: '別の著者$i',
          publisher: '別の出版社',
        ),
    ];

    final ranked = BookRepository.rankSearchResults(books, '村上春樹');
    expect(
      ranked.skip(15).take(5).every((book) => book.id.startsWith('title-')),
      isTrue,
    );
  });

  test('同じ優先度と一致度では楽天レビュー件数が多い本を優先する', () {
    final ranked = BookRepository.rankSearchResults([
      _book(
        id: 'less-popular',
        title: '検索する本 A',
        author: '著者',
        publisher: '出版社',
        reviewCount: 3,
      ),
      _book(
        id: 'popular',
        title: '検索する本 B',
        author: '著者',
        publisher: '出版社',
        reviewCount: 120,
      ),
    ], '検索する本');

    expect(ranked.first.id, 'popular');
  });
}
