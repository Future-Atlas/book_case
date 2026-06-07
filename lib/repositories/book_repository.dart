import '../data/book.dart';
import '../api/ndl_api.dart';
import '../api/rakuten_api.dart';

class BookRepository {
  /// Fetch all books (no query). Uses NDL API to search with empty string and enrich covers via Rakuten.
  Future<List<Book>> fetchAllBooks() async {
    // NDL API requires a title query; using empty string fetches a default set.
    final ndlBooks = await NdlApi.search('');
    // Enrich with cover images from Rakuten based on ISBN.
    final enriched = await RakutenApi.enrichWithCover(ndlBooks);
    return enriched;
  }

  /// Search books by query string.
  Future<List<Book>> searchBooks(String query) async {
    if (query.isEmpty) return fetchAllBooks();
    final ndlBooks = await NdlApi.search(query);
    final enriched = await RakutenApi.enrichWithCover(ndlBooks);
    return enriched;
  }
}
