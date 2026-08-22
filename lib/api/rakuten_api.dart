import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  static const String _proxyBaseUrl = String.fromEnvironment(
    'RAKUTEN_PROXY_BASE_URL',
  );
  static final Map<String, Book?> _bookByIdCache = <String, Book?>{};

  static bool get _hasDirectCredentials =>
      _appId.isNotEmpty && _accessKey.isNotEmpty;

  static bool _canRequestRakuten() {
    if (kIsWeb) return true;
    return _hasDirectCredentials || _proxyBaseUrl.trim().isNotEmpty;
  }

  static Uri _buildProxyUri(
    String endpoint,
    Map<String, String> queryParameters,
  ) {
    final params = <String, String>{'endpoint': endpoint, ...queryParameters};
    final trimmedBase = _proxyBaseUrl.trim();
    if (trimmedBase.isEmpty) {
      return Uri(path: '/api/rakuten', queryParameters: params);
    }

    final normalized = trimmedBase.endsWith('/')
        ? trimmedBase.substring(0, trimmedBase.length - 1)
        : trimmedBase;
    return Uri.parse('$normalized/api/rakuten').replace(
      queryParameters: params,
    );
  }

  static Future<http.Response?> _requestRakuten(
    String endpoint,
    Map<String, String> queryParameters,
  ) async {
    if (kIsWeb || !_hasDirectCredentials) {
      final proxyUri = _buildProxyUri(endpoint, queryParameters);
      return _getWithRateLimitRetry(proxyUri);
    }

    final baseUrl = endpoint == 'foreign' ? _foreignBookBaseUrl : _bookBaseUrl;
    final directUri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'format': 'json',
        ...queryParameters,
        'applicationId': _appId,
        'accessKey': _accessKey,
      },
    );
    return _getWithRateLimitRetry(directUri);
  }

  static List<String> buildSearchKeywordVariants(String keyword) {
    final original = keyword.trim();
    if (original.isEmpty) return const [];

    final separators = RegExp(r'[\s\u3000・･]+');
    final compact = original.replaceAll(separators, '');
    final variants = <String>{original, compact};

    // Rakuten's field-specific search does not always treat a middle dot as
    // optional. Search the first meaningful title segment as a fallback. For
    // input without separators, a six-character prefix provides the same
    // fallback (e.g. プロジェクトへイル -> プロジェクト).
    final hasMiddleDot = RegExp(r'[・･]').hasMatch(original);
    final segments = original
        .split(separators)
        .where((value) => value.length >= 2)
        .toList();
    if (hasMiddleDot && segments.length > 1) {
      variants.add(segments.first);
    } else if (compact.length > 6 && RegExp(r'[ぁ-んァ-ヶ一-龥]').hasMatch(compact)) {
      variants.add(compact.substring(0, 6));
    }

    return variants.where((value) => value.isNotEmpty).toList();
  }

  static Future<http.Response?> _getWithRateLimitRetry(
    Uri uri, {
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final response = await http.get(uri);

      if (response.statusCode != 429) {
        return response;
      }

      if (attempt == maxRetries) {
        return response;
      }

      final retryAfterHeader = response.headers['retry-after'];
      final retryAfterSeconds = int.tryParse(retryAfterHeader ?? '') ?? 1;
      final safeWait = retryAfterSeconds < 1 ? 1 : retryAfterSeconds;

      print(
        '⚠️ [RakutenApi] 429制限に到達。$safeWait秒待機して再試行します (${attempt + 1}/$maxRetries)',
      );
      await Future.delayed(Duration(seconds: safeWait));
    }

    return null;
  }

  static Future<Book?> fetchBookById(String bookId) async {
    if (bookId.trim().isEmpty || !_canRequestRakuten()) {
      return null;
    }

    final trimmed = bookId.trim();
    final cacheKey = trimmed.replaceAll('-', '');
    if (_bookByIdCache.containsKey(cacheKey)) {
      return _bookByIdCache[cacheKey];
    }

    final isbnLike = RegExp(r'^[0-9Xx-]{10,17}$').hasMatch(trimmed);

    final queryParameters = <String, String>{'hits': '1'};
    if (isbnLike) {
      queryParameters['isbn'] = trimmed.replaceAll('-', '');
    } else {
      queryParameters['keyword'] = trimmed;
    }

    try {
      final response = await _requestRakuten('book', queryParameters);
      if (response == null || response.statusCode != 200) {
        _bookByIdCache[cacheKey] = null;
        return null;
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final items = json['Items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return null;

      final item = items.first;
      final bookData = item['Item'];
      if (bookData is! Map<String, dynamic>) return null;

      final title = bookData['title'] as String? ?? '不明な書籍';
      final author = bookData['author'] as String? ?? '不明な著者';
      final publisher = bookData['publisherName'] as String? ?? '不明な出版社';
      final pubDate = bookData['salesDate'] as String? ?? '';
      final isbn = bookData['isbn'] as String? ?? '';

      String coverUrl = bookData['largeImageUrl'] as String? ?? '';
      if (coverUrl.isNotEmpty) {
        coverUrl =
            'https://images.weserv.nl/?url=${Uri.encodeComponent(coverUrl)}';
      }

      final description = bookData['itemCaption'] as String? ?? '';
      final rawReviewAverage = bookData['reviewAverage'];
      final parsedReviewAverage = rawReviewAverage is num
          ? rawReviewAverage.toDouble()
          : double.tryParse(rawReviewAverage?.toString() ?? '') ?? 0.0;
      final rawReviewCount = bookData['reviewCount'];
      final parsedReviewCount = rawReviewCount is num
          ? rawReviewCount.toInt()
          : int.tryParse(rawReviewCount?.toString() ?? '') ?? 0;

      final result = Book(
        id: isbn.isNotEmpty ? isbn : trimmed,
        title: title,
        author: author,
        publisher: publisher,
        pubDate: pubDate,
        isbn: isbn,
        coverUrl: coverUrl,
        ratingAvg: parsedReviewAverage,
        reviewCount: parsedReviewCount,
        description: description,
      );
      _bookByIdCache[cacheKey] = result;
      return result;
    } catch (_) {
      _bookByIdCache[cacheKey] = null;
      return null;
    }
  }

  static Future<List<Book>> searchBySelectedGenre({
    required String selectedGenre,
    int page = 1,
    int count = 10,
    bool keywordSearch = false,
    String? sort,
    String? searchField,
  }) async {
    if (!_canRequestRakuten()) {
      print('💡 [RakutenApi] APIキーが未設定のため通信をスキップします。');
      return [];
    }

    // 楽天APIの hits は上限があるため、要求件数を安全な範囲に収める。
    final effectiveCount = count.clamp(1, 30);

    var endpoint = 'book';
    final queryParameters = <String, String>{
      'page': '$page',
      'hits': '$effectiveCount',
    };

    // 💡 選択されたタブ・ジャンルによって、叩くAPIとパラメータを完全に切り替える
    if (keywordSearch) {
      // ホーム画面の取得とは分離し、楽天APIが正式に受け付ける
      // title / author / publisherName のいずれかを指定して検索する。
      const allowedFields = {'title', 'author', 'publisherName'};
      final field = allowedFields.contains(searchField)
          ? searchField!
          : 'title';
        queryParameters['booksGenreId'] = '001';
        queryParameters[field] = selectedGenre.trim();
        queryParameters['sort'] = sort ?? 'reviewCount';
    } else if (selectedGenre.contains('English') ||
        selectedGenre.contains('洋書')) {
      // ⭕ 洋書検索APIを呼び出す（必須条件：booksGenreId=005を指定）
        endpoint = 'foreign';
        queryParameters['booksGenreId'] = '005';
        queryParameters['sort'] = sort ?? 'reviewCount';
    } else {
      // ⭕ 通常の書籍検索API（日本語の本）を呼び出す
      String genreId = '001';
      String keyword = '';

      if (selectedGenre.contains('話題の本') || selectedGenre.contains('おすすめ')) {
        genreId = '001004'; // 小説・エッセイ
        sort ??= '-releaseDate';
      } else if (selectedGenre.contains('ビジネス') ||
          selectedGenre.contains('経済')) {
        genreId = '001006'; // ビジネス・経済・就職
      } else if (selectedGenre.contains('ベストセラー') ||
          selectedGenre.contains('人気作品')) {
        genreId = '001';
        sort ??= 'reviewCount';
      } else {
        keyword = selectedGenre;
      }

      queryParameters['booksGenreId'] = genreId;

      if (keyword.isNotEmpty) {
        queryParameters['keyword'] = keyword;
      }
      if (sort != null && sort.isNotEmpty) {
        queryParameters['sort'] = sort;
      }
    }

    print(
      '📡 [RakutenApi] リクエスト送信（$selectedGenre）：endpoint=$endpoint params=$queryParameters',
    );

    try {
      final response = await _requestRakuten(endpoint, queryParameters);

      if (response == null) {
        print('❌ [RakutenApi] レスポンス取得に失敗しました。');
        return [];
      }

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
        if (coverUrl.isNotEmpty) {
          coverUrl =
              'https://images.weserv.nl/?url=${Uri.encodeComponent(coverUrl)}';
        }

        final description = bookData['itemCaption'] as String? ?? '';
        final itemUrl = bookData['itemUrl'] as String? ?? '';
        final rawReviewAverage = bookData['reviewAverage'];
        final parsedReviewAverage = rawReviewAverage is num
            ? rawReviewAverage.toDouble()
            : double.tryParse(rawReviewAverage?.toString() ?? '') ?? 0.0;
        final rawReviewCount = bookData['reviewCount'];
        final parsedReviewCount = rawReviewCount is num
            ? rawReviewCount.toInt()
            : int.tryParse(rawReviewCount?.toString() ?? '') ?? 0;

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
            ratingAvg: parsedReviewAverage,
            reviewCount: parsedReviewCount,
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

  /// 検索欄に入力されたキーワードで楽天ブックスを直接検索する。
  /// ホーム画面ですでに取得した本の一覧やキャッシュは検索対象にしない。
  static Future<List<Book>> searchByKeyword({
    required String keyword,
    int page = 1,
    int count = 20,
    List<String>? searchFields,
  }) async {
    const allowedFields = {'title', 'author', 'publisherName'};
    final fields = (searchFields ?? const <String>[])
        .where(allowedFields.contains)
        .toSet()
        .toList();
    if (fields.isEmpty) {
      fields.addAll(const ['title', 'author', 'publisherName']);
    }
    final merged = <String, Book>{};
    final keywordVariants = buildSearchKeywordVariants(keyword);

    for (final field in fields) {
      for (final keywordVariant in keywordVariants) {
        final books = await searchBySelectedGenre(
          selectedGenre: keywordVariant,
          page: page,
          count: count,
          keywordSearch: true,
          searchField: field,
          sort: 'standard',
        );
        for (final book in books) {
          merged.putIfAbsent(book.id, () => book);
        }
      }
    }
    return merged.values.toList();
  }
}
