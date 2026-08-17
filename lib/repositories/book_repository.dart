import '../models/book.dart';
import '../api/rakuten_api.dart';
import '../services/content_safety_service.dart';

class BookRepository {
  BookRepository({this.allowAdultContent = false});

  final bool allowAdultContent;

  static String _normalizeForSearch(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^0-9a-zぁ-んァ-ヶ一-龥]+'), '');

  static int _matchQuality(String value, String query, List<String> tokens) {
    if (value == query) return 4;
    if (value.startsWith(query)) return 3;
    if (value.contains(query)) return 2;
    if (tokens.isNotEmpty && tokens.every(value.contains)) return 1;
    return 0;
  }

  static int _searchScore(Book book, String rawQuery) {
    final query = _normalizeForSearch(rawQuery);
    if (query.isEmpty) return 0;
    final tokens = rawQuery
        .split(RegExp(r'[\s\u3000・･]+'))
        .map(_normalizeForSearch)
        .where((token) => token.isNotEmpty)
        .toList();
    final title = _normalizeForSearch(book.title);
    final author = _normalizeForSearch(book.author);
    final publisher = _normalizeForSearch(book.publisher);
    final fields = query.length < 8
        ? [author, publisher, title]
        : [title, author, publisher];

    for (var index = 0; index < fields.length; index++) {
      final quality = _matchQuality(fields[index], query, tokens);
      if (quality > 0) return (quality * 1000) + ((3 - index) * 100);
    }
    return 0;
  }

  static List<Book> rankSearchResults(Iterable<Book> source, String query) {
    final books = source.toList();
    books.sort((a, b) {
      final relevance = _searchScore(b, query) - _searchScore(a, query);
      if (relevance != 0) return relevance;
      final reviews = b.reviewCount.compareTo(a.reviewCount);
      if (reviews != 0) return reviews;
      final rating = b.ratingAvg.compareTo(a.ratingAvg);
      if (rating != 0) return rating;
      return a.title.compareTo(b.title);
    });
    return books;
  }

  List<Book> _filterForViewer(List<Book> books) {
    return ContentSafetyService.filterBooks(
      books,
      allowAdultContent: allowAdultContent,
    );
  }

  /// 📌 1. トップ画面の各セクション（おすすめ・洋書・人気）の追加読み込み用
  /// ここでは最初から表紙画像が確実に手に入る楽天APIをページ指定で動かします。
  Future<List<Book>> fetchBooksByGenre(String genre, {int page = 1}) async {
    try {
      print('📦 [Repository] 楽天APIからジャンル本を取得します: $genre (Page: $page)');

      // ⏱️【429エラー（連打）対策】
      // コントローラーが一斉に複数のジャンルを要求してきた際、
      // 楽天APIがパンクして429エラーを返さないよう、通信の直前に必ず「1秒の休憩」を挟みます。
      await Future.delayed(const Duration(seconds: 1));

      // 楽天APIの searchBySelectedGenre を直接呼び出す
      final isRecommended = genre.contains('話題の本') || genre.contains('おすすめ');
      final rakutenBooks = await RakutenApi.searchBySelectedGenre(
        selectedGenre: genre,
        page: page,
        count: isRecommended ? 30 : 10,
      );
      final filtered = _filterForViewer(rakutenBooks);
      if (isRecommended) {
        filtered.sort((a, b) {
          final reviews = b.reviewCount.compareTo(a.reviewCount);
          if (reviews != 0) return reviews;
          return b.ratingAvg.compareTo(a.ratingAvg);
        });
        return filtered.take(10).toList();
      }
      return filtered;
    } catch (e) {
      print('❌ [Repository] 楽天ジャンル本の取得でエラーが発生しました: $e');
      return [];
    }
  }

  /// 📌 2. 全件取得（初期表示用など）
  /// 楽天APIから取得します。
  Future<List<Book>> fetchAllBooks() async {
    try {
      print('📦 [Repository] 楽天APIから全件（初期表示）を取得します');
      final rakutenBooks = await RakutenApi.searchBySelectedGenre(
        selectedGenre: '',
        page: 1,
        count: 10,
      );
      return _filterForViewer(rakutenBooks);
    } catch (e) {
      print('❌ [Repository] 楽天全件取得でエラーが発生しました: $e');
      return [];
    }
  }

  /// 📌 3. 検索窓からのキーワード検索（網羅性重視）
  /// 楽天APIでキーワード検索を行います。
  Future<List<Book>> searchBooks(
    String query, {
    int page = 1,
    int count = 10,
  }) async {
    if (query.isEmpty) return fetchAllBooks();
    if (!allowAdultContent && ContentSafetyService.isAdultSearchQuery(query)) {
      return [];
    }

    try {
      print('📦 [Repository] 楽天APIからキーワード検索を行います: $query (Page: $page)');

      final rakutenBooks = await RakutenApi.searchByKeyword(
        keyword: query,
        page: page,
        count: count,
      );
      return rankSearchResults(
        _filterForViewer(rakutenBooks),
        query,
      ).take(count).toList();
    } catch (e) {
      print('❌ [Repository] 楽天検索でエラーが発生しました: $e');
      return [];
    }
  }
}
