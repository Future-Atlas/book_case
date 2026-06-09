import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/book.dart';

class RakutenApi {
  // 🇯🇵 日本語の本専用エンドポイント（booksGenreId=001 系列）
  static const String _bookBaseUrl =
      'https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404';

  // 🇺🇸 洋書専用エンドポイント（booksGenreId=005 系列）
  static const String _foreignBookBaseUrl =
      'https://openapi.rakuten.co.jp/services/api/BooksForeignBook/Search/20170404';

  static const String _appId = String.fromEnvironment('RAKUTEN_APP_ID');
  static const String _accessKey = String.fromEnvironment('RAKUTEN_ACCESS_KEY');

  static Future<List<Book>> searchBySelectedGenre({
    required String selectedGenre,
    int page = 1,
    int count = 10,
  }) async {
    if (_appId.isEmpty || _accessKey.isEmpty) {
      print('💡 [RakutenApi] APIキーが未設定のため通信をスキップします。');
      return [];
    }

    String urlString = '';

    // 💡 選択されたタブ・ジャンルによって、叩くAPIとパラメータを完全に切り替える
    if (selectedGenre.contains('English') || selectedGenre.contains('洋書')) {
      // ⭕ 洋書検索APIを呼び出す（必須条件：booksGenreId=005を指定）
      urlString =
          '$_foreignBookBaseUrl?format=json&page=$page&hits=$count&applicationId=$_appId&accessKey=$_accessKey&booksGenreId=005';
    } else {
      // ⭕ 通常の書籍検索API（日本語の本）を呼び出す
      String genreId = '001';
      String keyword = '';

      if (selectedGenre.contains('話題の本') || selectedGenre.contains('おすすめ')) {
        genreId = '001004'; // 小説・エッセイ
      } else if (selectedGenre.contains('ビジネス') ||
          selectedGenre.contains('経済')) {
        genreId = '001006'; // ビジネス・経済・就職
      } else if (selectedGenre.contains('ベストセラー') ||
          selectedGenre.contains('人気作品')) {
        genreId = '001';
        keyword = 'ベストセラー';
      } else {
        keyword = selectedGenre;
      }

      urlString =
          '$_bookBaseUrl?format=json&page=$page&hits=$count&applicationId=$_appId&accessKey=$_accessKey&booksGenreId=$genreId';

      if (keyword.isNotEmpty) {
        urlString += '&keyword=${Uri.encodeComponent(keyword)}';
      }
    }

    print('📡 [RakutenApi] リクエスト送信（$selectedGenre）：$urlString');

    try {
      final uri = Uri.parse(urlString);
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        print(
          '❌ [RakutenApi] HTTPエラー: ${response.statusCode} - ${response.body}',
        );
        return [];
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final items = json['Items'] as List<dynamic>? ?? [];
      final List<Book> books = [];

      // 💡 楽天ブックス系APIは、レスポンスのネスト構造が共通しているためパース処理は一括化できます
      for (var item in items) {
        final bookData = item['Item'];

        final title = bookData['title'] as String? ?? 'Unknown Title';
        final author = bookData['author'] as String? ?? 'Unknown Author';
        final publisher =
            bookData['publisherName'] as String? ?? 'Unknown Publisher';
        final pubDate = bookData['salesDate'] as String? ?? '';
        final isbn = bookData['isbn'] as String? ?? '';

        String coverUrl = bookData['largeImageUrl'] as String? ?? '';

        final description = bookData['itemCaption'] as String? ?? '';
        final itemUrl = bookData['itemUrl'] as String? ?? '';

        books.add(
          Book(
            id: isbn.isNotEmpty
                ? isbn
                : (itemUrl.isNotEmpty ? itemUrl : UniqueKey().toString()),
            title: title,
            author: author,
            publisher: publisher,
            pubDate: pubDate,
            isbn: isbn,
            coverUrl: coverUrl,
            genre: selectedGenre,
            description: description,
          ),
        );
      }

      print('✨ [RakutenApi] データ取得成功（$selectedGenre）：${books.length} 件');
      return books;
    } catch (e) {
      print('❌ [RakutenApi] エラー発生: $e');
      return [];
    }
  }
}
