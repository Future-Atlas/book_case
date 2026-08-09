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

    if (reset) {
      hasMoreSearch = true;
      searchPage = 1;
      searchResults = [];
      _searchResultIds.clear();
    } else if (!hasMoreSearch || isSearching) {
      return;
    }

    isSearching = true;
    notifyListeners();

    const maxPagesPerSearch = 20;
    var fetchedPages = 0;

    try {
      while (searchResults.length < 10 && hasMoreSearch) {
        if (query != searchQuery.trim()) {
          return;
        }

        if (fetchedPages >= maxPagesPerSearch) {
          hasMoreSearch = false;
          break;
        }

        final batch = await _repository.searchBooks(
          query,
          page: searchPage,
          count: 100,
        );
        searchPage += 1;
        fetchedPages += 1;

        if (batch.isEmpty) {
          hasMoreSearch = false;
          break;
        }

        for (final book in batch) {
          if (_searchResultIds.contains(book.id)) continue;
          if (!_matchesQuery(book, query)) continue;
          _searchResultIds.add(book.id);
          searchResults.add(book);
        }
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
