import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../data/book.dart';

class RakutenApi {
  static final String _baseUrl = 'https://app.rakuten.co.jp/services/api/BooksBook/Search/20170404';
  static final String _appId = dotenv.env['RAKUTEN_APP_ID'] ?? '';

  /// ISBN が分かっている本の表紙画像 URL を取得し、Book にマージして返す
  static Future<List<Book>> enrichWithCover(List<Book> books) async {
    List<Book> enriched = [];
    for (final book in books) {
      if (book.isbn.isEmpty) {
        enriched.add(book);
        continue;
      }
      final uri = Uri.parse('$_baseUrl?applicationId=$_appId&isbn=${book.isbn}&format=json');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final items = json['Items'] as List<dynamic>? ?? [];
        if (items.isNotEmpty) {
          final coverUrl = items.first['Item']['largeImageUrl'] as String? ?? '';
          enriched.add(book.copyWith(coverUrl: coverUrl));
          continue;
        }
      }
      enriched.add(book);
    }
    return enriched;
  }
}
