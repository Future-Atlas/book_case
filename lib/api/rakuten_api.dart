import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/book.dart';

class RakutenApi {
  // ⭕ 楽天新API公式エンドポイント
  static const String _baseUrl =
      'https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404';

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

    // 新APIの仕様に基づき、適切なデフォルト値（本ジャンル: 001）を設定
    String genreId = '001';
    String keyword = '';

    // ジャンルマッピングの完全修正版
    if (selectedGenre.contains('話題の本') || selectedGenre.contains('おすすめ')) {
      genreId = '001004'; // 小説・エッセイ（日本語）
    } else if (selectedGenre.contains('ビジネス') || selectedGenre.contains('経済')) {
      genreId = '001006'; // ビジネス・経済・就職（日本語）
    } else if (selectedGenre.contains('English') ||
        selectedGenre.contains('洋書')) {
      // ⭕【新API完全対応】3桁の「005」はエラー・無視の原因になります。
      // 新APIのバリデーションを通すため、洋書の主要サブジャンルである「005001（洋書/小説・エッセイ）」
      // または「005011（洋書/語学・学習）」などを正確に指定します。
      // ここでは最も一般的な「洋書総合・小説」をターゲットにするため「005001」を指定します。
      genreId = '005001';
      keyword = ''; // ジャンルが「洋書」に固定されるため、キーワードは空でOKです
    } else if (selectedGenre.contains('ベストセラー') ||
        selectedGenre.contains('人気作品')) {
      genreId = '001'; // 通常の「本」トップ
      keyword = 'ベストセラー';
    } else {
      keyword = selectedGenre;
    }

    // 各パラメータをエンコードしてURLを構築（新APIはkeywordに対応しています）
    String urlString =
        '$_baseUrl?format=json&page=$page&hits=$count&applicationId=$_appId&accessKey=$_accessKey&booksGenreId=$genreId';

    if (keyword.isNotEmpty) {
      urlString += '&keyword=${Uri.encodeComponent(keyword)}';
    }

    print('📡 [RakutenApi] 新APIサーバーへリクエスト送信: $urlString');

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

      for (var item in items) {
        final bookData = item['Item'];

        final title = bookData['title'] as String? ?? '不明なタイトル';
        final author = bookData['author'] as String? ?? '不明な著者';
        final publisher = bookData['publisherName'] as String? ?? '不明な出版社';
        final pubDate = bookData['salesDate'] as String? ?? '';
        final isbn = bookData['isbn'] as String? ?? '';

        // 画像プロキシ（安定性の高い海外サーバー経由）
        String coverUrl = bookData['largeImageUrl'] as String? ?? '';
        if (coverUrl.isNotEmpty) {
          coverUrl =
              'https://images.weserv.nl/?url=${Uri.encodeComponent(coverUrl)}';
        }

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

      print('✨ [RakutenApi] 新データ取得成功（$selectedGenre）：${books.length} 件');
      return books;
    } catch (e) {
      print('❌ [RakutenApi] エラー発生: $e');
      return [];
    }
  }
}
