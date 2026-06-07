import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/book.dart';

class NdlApi {
  static const _baseUrl = 'https://iss.ndl.go.jp/api/opensearch';

  /// 検索クエリで書籍情報を取得し、Book オブジェクトのリストを返す（簡易実装）
  static Future<List<Book>> search(String query) async {
    final uri = Uri.parse('$_baseUrl?title=$query&mediatype=1');
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final json = jsonDecode(response.body);
    final items = json['channel']?['item'] as List<dynamic>? ?? [];
    return items.map((e) => Book.fromNdlJson(e as Map<String, dynamic>)).toList();
  }
}
