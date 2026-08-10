import 'dart:async';

import 'package:flutter/material.dart';
import '../models/book.dart';
import '../repositories/book_repository.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';

class BookListController extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  Timer? _searchDebounce;
  bool isLoading = true;

  bool isSearching = false;
  bool hasMoreSearch = true;
  int searchPage = 1;
  List<Book> searchResults = [];
  final Set<String> _searchResultIds = <String>{};
  List<String> _searchVariants = [];
  int _searchVariantIndex = 0;
  int _searchVariantPage = 1;

  // ジャンルごとに「リスト」「現在のページ」「まだ続きがあるか」を独立して管理
  List<Book> recommendedBooks = [];
  int recommendedPage = 1;
  bool hasMoreRecommended = true;
  bool isLoadingMoreRecommended = false;

  List<Book> westernBooks = [];
  int westernPage = 1;
  bool hasMoreWestern = true;
  bool isLoadingMoreWestern = false;

  List<Book> popularBooks = [];
  int popularPage = 1;
  bool hasMorePopular = true;
  bool isLoadingMorePopular = false;

  // タイムライン用
  List<Post> timelinePosts = [];
  bool _allowAdultContent = false;

  BookRepository get _repository =>
      BookRepository(allowAdultContent: _allowAdultContent);

  // 初期化
  void initialize(BuildContext context) {
    _loadData(context);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    searchQuery = searchController.text.trim();
    _searchDebounce?.cancel();

    if (searchQuery.isEmpty) {
      isSearching = false;
      hasMoreSearch = true;
      searchPage = 1;
      _searchVariants = [];
      _searchVariantIndex = 0;
      _searchVariantPage = 1;
      searchResults = [];
      _searchResultIds.clear();
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchUntilTen(reset: true);
    });
  }

  String _normalizeForSearch(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^0-9a-zぁ-んァ-ヶ一-龥]+'), '');
  }

  List<String> _buildSearchVariants(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return const [];

    final variants = <String>[];

    void addVariant(String value) {
      final v = value.trim();
      if (v.isEmpty) return;
      if (v.length < 2) return;
      if (!variants.contains(v)) {
        variants.add(v);
      }
    }

    final compact = query.replaceAll(RegExp(r'[\s\u3000・･]+'), '');
    final spacedFromDot = query.replaceAll(RegExp(r'[・･]+'), ' ');
    final noDot = query.replaceAll(RegExp(r'[・･]+'), '');

    addVariant(query);
    addVariant(compact);
    addVariant(spacedFromDot);
    addVariant(noDot);

    final splitTokens = spacedFromDot
        .split(RegExp(r'[\s\u3000]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (splitTokens.length >= 2) {
      addVariant(splitTokens.join(' '));
      addVariant(splitTokens.join('・'));
      for (final token in splitTokens) {
        addVariant(token);
      }
    }

    if (compact.length >= 6) {
      final mid = compact.length ~/ 2;
      addVariant(compact.substring(0, mid));
      addVariant(compact.substring(mid));

      final tailLength = compact.length >= 8 ? 8 : compact.length;
      addVariant(compact.substring(compact.length - tailLength));
    }

    return variants;
  }

  int _scoreBook(Book book, String rawQuery) {
    final query = _normalizeForSearch(rawQuery);
    if (query.isEmpty) return 0;

    final normalizedTitle = _normalizeForSearch(book.title);
    final normalizedAuthor = _normalizeForSearch(book.author);
    final normalizedDescription = _normalizeForSearch(book.description);

    var score = 0;

    if (normalizedTitle == query) score += 500;
    if (normalizedTitle.startsWith(query)) score += 300;
    if (normalizedTitle.contains(query)) score += 200;
    if (normalizedAuthor.contains(query)) score += 120;
    if (normalizedDescription.contains(query)) score += 60;

    final tokens = rawQuery
        .split(RegExp(r'[\s\u3000・･]+'))
        .map(_normalizeForSearch)
        .where((token) => token.isNotEmpty)
        .toList();

    for (final token in tokens) {
      if (normalizedTitle.contains(token)) score += 40;
      if (normalizedAuthor.contains(token)) score += 24;
      if (normalizedDescription.contains(token)) score += 10;
    }

    return score;
  }

  void _sortSearchResults(String rawQuery) {
    searchResults.sort((a, b) {
      final scoreDiff = _scoreBook(b, rawQuery) - _scoreBook(a, rawQuery);
      if (scoreDiff != 0) return scoreDiff;
      return a.title.compareTo(b.title);
    });
  }

  bool _matchesQuery(Book book, String rawQuery) {
    final normalizedQuery = _normalizeForSearch(rawQuery);
    if (normalizedQuery.isEmpty) return false;

    final tokens = rawQuery
        .toLowerCase()
        .split(RegExp(r'[\s\u3000]+'))
        .map(_normalizeForSearch)
        .where((token) => token.isNotEmpty)
        .toList();

    final target = _normalizeForSearch(
      '${book.title} ${book.author} ${book.description}',
    );

    if (tokens.isEmpty) {
      return target.contains(normalizedQuery);
    }

    // 複数語検索は全トークン一致（AND）にしてノイズを抑える。
    return tokens.every(target.contains);
  }

  Future<void> _searchUntilTen({required bool reset}) async {
    final query = searchQuery.trim();
    if (query.isEmpty) {
      isSearching = false;
      notifyListeners();
      return;
    }

    final targetCount = reset ? 10 : searchResults.length + 10;

    if (reset) {
      hasMoreSearch = true;
      searchPage = 1;
      _searchVariants = _buildSearchVariants(query);
      _searchVariantIndex = 0;
      _searchVariantPage = 1;
      searchResults = [];
      _searchResultIds.clear();
    } else if (!hasMoreSearch || isSearching) {
      return;
    }

    isSearching = true;
    notifyListeners();

    const maxRequestsPerRun = 12;
    const maxPagesPerVariant = 6;
    var requestCount = 0;

    try {
      while (searchResults.length < targetCount && hasMoreSearch) {
        if (query != searchQuery.trim()) {
          return;
        }

        if (_searchVariantIndex >= _searchVariants.length) {
          hasMoreSearch = false;
          break;
        }

        if (requestCount >= maxRequestsPerRun) {
          break;
        }

        final activeVariant = _searchVariants[_searchVariantIndex];

        final batch = await _repository.searchBooks(
          activeVariant,
          page: _searchVariantPage,
          count: 100,
        );
        searchPage += 1;
        _searchVariantPage += 1;
        requestCount += 1;

        if (batch.isEmpty) {
          _searchVariantIndex += 1;
          _searchVariantPage = 1;
          continue;
        }

        for (final book in batch) {
          if (_searchResultIds.contains(book.id)) continue;
          if (!_matchesQuery(book, query)) continue;
          _searchResultIds.add(book.id);
          searchResults.add(book);
        }

        _sortSearchResults(query);

        if (_searchVariantPage > maxPagesPerVariant) {
          _searchVariantIndex += 1;
          _searchVariantPage = 1;
        }
      }

      if (_searchVariantIndex >= _searchVariants.length) {
        hasMoreSearch = false;
      }
    } finally {
      if (query == searchQuery.trim()) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSearchResults() async {
    if (searchQuery.isEmpty) return;
    await _searchUntilTen(reset: false);
    notifyListeners();
  }

  Future<void> _loadData(BuildContext context) async {
    isLoading = true;
    notifyListeners();

    _allowAdultContent = await SupabaseService().canViewAdultContent();
    final repository = _repository;

    recommendedPage = 1;
    westernPage = 1;
    popularPage = 1;
    hasMoreRecommended = true;
    hasMoreWestern = true;
    hasMorePopular = true;

    try {
      recommendedBooks = await repository.fetchBooksByGenre(
        '話題の本',
        page: recommendedPage,
      );
      hasMoreRecommended = recommendedBooks.length >= 10;
    } catch (e) {
      print('おすすめ本の取得でエラーが発生しました: $e');
      recommendedBooks = [];
      hasMoreRecommended = false;
    }

    try {
      westernBooks = await repository.fetchBooksByGenre(
        'English',
        page: westernPage,
      );
      hasMoreWestern = westernBooks.length >= 10;
    } catch (e) {
      print('洋書の取得でエラーが発生しました: $e');
      westernBooks = [];
      hasMoreWestern = false;
    }

    try {
      popularBooks = await repository.fetchBooksByGenre(
        'ベストセラー',
        page: popularPage,
      );
      hasMorePopular = popularBooks.length >= 10;
    } catch (e) {
      print('人気作品の取得でエラーが発生しました: $e');
      popularBooks = [];
      hasMorePopular = false;
    }

    try {
      timelinePosts = await SupabaseService().fetchTimelinePosts();
    } catch (e) {
      print('Supabaseの接続エラー: $e');
      timelinePosts = [];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreRecommended() async {
    if (isLoadingMoreRecommended || !hasMoreRecommended) return;
    isLoadingMoreRecommended = true;
    notifyListeners();

    try {
      final nextPage = recommendedPage + 1;
      print('📡 おすすめ本の次のページを取得中... (Page: $nextPage)');

      final newBooks = await _repository.fetchBooksByGenre(
        '話題の本',
        page: nextPage,
      );

      if (newBooks.isEmpty) {
        hasMoreRecommended = false;
      } else {
        recommendedBooks = newBooks;
        recommendedPage = nextPage;
        hasMoreRecommended = newBooks.length >= 10;
      }
    } catch (e) {
      print('おすすめ本の追加取得エラー: $e');
    } finally {
      isLoadingMoreRecommended = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreWestern() async {
    if (isLoadingMoreWestern || !hasMoreWestern) return;
    isLoadingMoreWestern = true;
    notifyListeners();

    try {
      final nextPage = westernPage + 1;
      print('📡 洋書の次のページを取得中... (Page: $nextPage)');

      final newBooks = await _repository.fetchBooksByGenre(
        'English',
        page: nextPage,
      );

      if (newBooks.isEmpty) {
        hasMoreWestern = false;
      } else {
        westernBooks = newBooks;
        westernPage = nextPage;
        hasMoreWestern = newBooks.length >= 10;
      }
    } catch (e) {
      print('洋書の追加取得エラー: $e');
    } finally {
      isLoadingMoreWestern = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePopular() async {
    if (isLoadingMorePopular || !hasMorePopular) return;
    isLoadingMorePopular = true;
    notifyListeners();

    try {
      final nextPage = popularPage + 1;
      print('📡 人気作品の次のページを取得中... (Page: $nextPage)');

      final newBooks = await _repository.fetchBooksByGenre(
        'ベストセラー',
        page: nextPage,
      );

      if (newBooks.isEmpty) {
        hasMorePopular = false;
      } else {
        popularBooks = newBooks;
        popularPage = nextPage;
        hasMorePopular = newBooks.length >= 10;
      }
    } catch (e) {
      print('人気作品の追加取得エラー: $e');
    } finally {
      isLoadingMorePopular = false;
      notifyListeners();
    }
  }

  Future<void> loadData(BuildContext context) async => _loadData(context);

  List<Book> get books => [
    ...recommendedBooks,
    ...westernBooks,
    ...popularBooks,
  ];
}
