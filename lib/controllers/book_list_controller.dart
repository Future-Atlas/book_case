import 'package:flutter/material.dart';
import '../models/book.dart';
import '../repositories/book_repository.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';

class BookListController extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  bool isLoading = true;

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

  // 初期化
  void initialize(BuildContext context) {
    _loadData(context);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    searchQuery = searchController.text;
    notifyListeners();
  }

  Future<void> _loadData(BuildContext context) async {
    isLoading = true;
    notifyListeners();

    final repository = BookRepository();

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
    } catch (e) {
      print('おすすめ本の取得でエラーが発生しました: $e');
      recommendedBooks = [];
    }

    try {
      westernBooks = await repository.fetchBooksByGenre(
        'English',
        page: westernPage,
      );
    } catch (e) {
      print('洋書の取得でエラーが発生しました: $e');
      westernBooks = [];
    }

    try {
      popularBooks = await repository.fetchBooksByGenre(
        'ベストセラー',
        page: popularPage,
      );
    } catch (e) {
      print('人気作品の取得でエラーが発生しました: $e');
      popularBooks = [];
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

  // 🛠️ 変更点: 裏でサイレントに通信し、データが合体したタイミングで1回だけ画面に通知する

  // おすすめ本の追加（順次読み込み）
  Future<void> loadMoreRecommended() async {
    if (isLoadingMoreRecommended || !hasMoreRecommended) return;
    isLoadingMoreRecommended = true;
    // 📌 通信前の notifyListeners() を削除（画面のガクつき・暴走を防ぐため）

    try {
      final nextPage = recommendedPage + 1;
      print('📡 おすすめ本の次のページを取得中... (Page: $nextPage)');

      final newBooks = await BookRepository().fetchBooksByGenre(
        '話題の本',
        page: nextPage,
      );

      if (newBooks.isEmpty) {
        hasMoreRecommended = false;
      } else {
        recommendedBooks.addAll(newBooks); // 後ろに追加合体
        recommendedPage = nextPage; // 成功時のみページを進める
      }
    } catch (e) {
      print('おすすめ本の追加取得エラー: $e');
    } finally {
      isLoadingMoreRecommended = false;
      notifyListeners(); // 📌 結合が終わったこの瞬間だけ画面を更新！
    }
  }

  // 洋書の追加（順次読み込み）
  Future<void> loadMoreWestern() async {
    if (isLoadingMoreWestern || !hasMoreWestern) return;
    isLoadingMoreWestern = true;

    try {
      final nextPage = westernPage + 1;
      print('📡 洋書の次のページを取得中... (Page: $nextPage)');

      final newBooks = await BookRepository().fetchBooksByGenre(
        'English',
        page: nextPage,
      );

      if (newBooks.isEmpty) {
        hasMoreWestern = false;
      } else {
        westernBooks.addAll(newBooks);
        westernPage = nextPage;
      }
    } catch (e) {
      print('洋書の追加取得エラー: $e');
    } finally {
      isLoadingMoreWestern = false;
      notifyListeners();
    }
  }

  // 人気作品の追加（順次読み込み）
  Future<void> loadMorePopular() async {
    if (isLoadingMorePopular || !hasMorePopular) return;
    isLoadingMorePopular = true;

    try {
      final nextPage = popularPage + 1;
      print('📡 人気作品の次のページを取得中... (Page: $nextPage)');

      final newBooks = await BookRepository().fetchBooksByGenre(
        'ベストセラー',
        page: nextPage,
      );

      if (newBooks.isEmpty) {
        hasMorePopular = false;
      } else {
        popularBooks.addAll(newBooks);
        popularPage = nextPage;
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
