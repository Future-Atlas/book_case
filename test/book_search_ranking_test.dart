import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/book.dart';
import 'package:flutter_application_1/repositories/book_repository.dart';

Book _book({
  required String id,
  required String title,
  required String author,
  required String publisher,
  int reviewCount = 0,
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
  );
}

void main() {
  test('8文字未満は著者、出版社、タイトルの順で完全一致を優先する', () {
    final ranked = BookRepository.rankSearchResults([
      _book(id: 'title', title: '村上', author: '別の著者', publisher: '別の出版社'),
      _book(id: 'publisher', title: '別の本', author: '別の著者', publisher: '村上'),
      _book(id: 'author', title: '別の本', author: '村上', publisher: '別の出版社'),
    ], '村上');

    expect(ranked.map((book) => book.id), ['author', 'publisher', 'title']);
  });

  test('8文字以上はタイトル、著者、出版社の順で完全一致を優先する', () {
    const query = 'プロジェクトヘイルメアリー';
    final ranked = BookRepository.rankSearchResults([
      _book(id: 'publisher', title: '別の本', author: '別の著者', publisher: query),
      _book(id: 'author', title: '別の本', author: query, publisher: '別の出版社'),
      _book(id: 'title', title: query, author: '別の著者', publisher: '別の出版社'),
    ], query);

    expect(ranked.map((book) => book.id), ['title', 'author', 'publisher']);
  });

  test('関連度が同じ場合は楽天レビュー件数が多い本を優先する', () {
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
