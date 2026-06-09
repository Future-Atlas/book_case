import '../models/book.dart';
import '../api/ndl_api.dart';
import '../api/rakuten_api.dart';

class BookRepository {
  /// 📌 1. トップ画面の各セクション（おすすめ・洋書・人気）の追加読み込み用
  /// ここでは最初から表紙画像が確実に手に入る楽天APIをページ指定で動かします。
  Future<List<Book>> fetchBooksByGenre(String genre, {int page = 1}) async {
    try {
      print('📦 [Repository] 楽天APIからジャンル本を取得します: $genre (Page: $page)');
      // 楽天APIの searchBySelectedGenre を直接呼び出す
      final rakutenBooks = await RakutenApi.searchBySelectedGenre(
        selectedGenre: genre,
        page: page,
        count: 10,
      );
      return rakutenBooks;
    } catch (e) {
      print('❌ [Repository] 楽天ジャンル本の取得でエラーが発生しました: $e');
      return [];
    }
  }

  /// 📌 2. 全件取得（初期表示用など）
  /// 網羅性を重視するため、国会図書館APIを使用します。
  Future<List<Book>> fetchAllBooks() async {
    try {
      print('📦 [Repository] 国会図書館APIから全件（初期表示）を取得します');
      final ndlBooks = await NdlApi.searchBySelectedGenre(
        selectedGenre: '', // 空文字で全ジャンル
        page: 1,
        count: 10,
      );
      return ndlBooks;
    } catch (e) {
      print('❌ [Repository] 国会図書館全件取得でエラーが発生しました: $e');
      return [];
    }
  }

  /// 📌 3. 検索窓からのキーワード検索（網羅性重視）
  /// すべての図書が見えるように、国会図書館APIを直接使用します！
  Future<List<Book>> searchBooks(String query, {int page = 1}) async {
    if (query.isEmpty) return fetchAllBooks();

    try {
      print('📦 [Repository] 国会図書館APIからキーワード検索を行います: $query (Page: $page)');
      // 国会図書館APIの searchBySelectedGenre を呼び出す
      // 前のステップで ndl_api.dart は自由なキーワード（any）に対応させてあります
      final ndlBooks = await NdlApi.searchBySelectedGenre(
        selectedGenre: query,
        page: page,
        count: 10,
      );
      return ndlBooks;
    } catch (e) {
      print('❌ [Repository] 国会図書館検索でエラーが発生しました: $e');
      return [];
    }
  }
}
