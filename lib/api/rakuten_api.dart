import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/book.dart';

class RakutenApi {
  // ✨ 修正：他のセクションと同じ、最高に安定している従来版のエンドポイントに変更
  static const String _baseUrl =
      'https://app.rakuten.co.jp/services/api/BooksBook/Search/20170404';

  // env.json から安全にロード（安定版は _appId のみで動きます）
  static const String _appId = String.fromEnvironment('RAKUTEN_APP_ID');

  static Future<List<Book>> searchBySelectedGenre({
    required String selectedGenre,
    int page = 1,
    int count = 10,
  }) async {
    // 💡 _appId のみのチェックにシンプル化
    if (_appId.isEmpty) {
      print('💡 [RakutenApi] ローカル環境またはキー未設定のため、通信をスキップします。');
      return [];
    }

    String genreId = '';
    String keyword = '';

    // ジャンルマッピング
    if (selectedGenre.contains('話題の本') ||
        selectedGenre.contains('おすすめ') ||
        selectedGenre.contains('小説') ||
        selectedGenre.contains('文学')) {
      genreId = '001004';
    } else if (selectedGenre.contains('ビジネス') || selectedGenre.contains('経済')) {
      genreId = '001006';
    } else if (selectedGenre.contains('English') ||
        selectedGenre.contains('洋書')) {
      genreId = '005'; // 💡 安定版APIなら、この洋書ジャンルIDも100%正常に受け付けます！
    } else if (selectedGenre.contains('ベストセラー') ||
        selectedGenre.contains('人気')) {
      keyword = 'ベストセラー';
    } else if (selectedGenre.contains('社会') || selectedGenre.contains('法律')) {
      genreId = '001007';
    } else if (selectedGenre.contains('自然科学') ||
        selectedGenre.contains('数学') ||
        selectedGenre.contains('医学')) {
      genreId = '001012';
    } else if (selectedGenre.contains('アート') ||
        selectedGenre.contains('芸術') ||
        selectedGenre.contains('スポーツ')) {
      genreId = '001009';
    } else {
      keyword = selectedGenre;
    }

    // ✨ 修正：安定版のクエリ組み立て（accessKeyを削除）
    String urlString =
        '$_baseUrl?format=json&page=$page&hits=$count&applicationId=$_appId';

    if (genreId.isNotEmpty) {
      urlString += '&booksGenreId=$genreId';
    }
    if (keyword.isNotEmpty) {
      urlString += '&keyword=${Uri.encodeComponent(keyword)}';
    }

    print('📡 [RakutenApi] 安定版楽天サーバーへリクエストを送信します（ジャンル: $selectedGenre）');

    try {
      final uri = Uri.parse(urlString);
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        print('❌ [RakutenApi] HTTPエラー: ${response.statusCode}');
        return [];
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final items = json['Items'] as List<dynamic>? ?? [];
      final List<Book> books = [];

      for (var item in items) {
        final bookData = item['Item'];

        final title = bookData['title'] as String? ?? '不明なタイトル';
        final author = bookData['author'] as String? ?? '不明な著者';
        final publisher = bookData['publisherName'] as String? ?? '不明な出版社';
        final pubDate = bookData['salesDate'] as String? ?? '';
        final isbn = bookData['isbn'] as String? ?? '';
        final coverUrl = bookData['largeImageUrl'] as String? ?? '';
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

      print('✨ [RakutenApi] 安定版データ取得成功：${books.length} 件');
      return books;
    } catch (e) {
      print('❌ [RakutenApi] 通信エラー: $e');
      return [];
    }
  }

  static Future<List<Book>> enrichWithCover(List<Book> books) async {
    return books;
  }
}
