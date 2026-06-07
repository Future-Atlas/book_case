import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/book.dart';
import '../repositories/book_repository.dart';
import '../models/post.dart';


class BookListController extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  List<Book> books = [];
  List<Post> timelinePosts = [];
  bool isLoading = true;

  void initialize(BuildContext context) {
    _loadData(context);
    searchController.addListener(_onSearchChanged);
  }

  void disposeController() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
  }

  void _onSearchChanged() {
    searchQuery = searchController.text;
    notifyListeners();
  }

  Future<void> _loadData(BuildContext context) async {
    isLoading = true;
    notifyListeners();
    final repository = BookRepository();
    // Load all books (empty query fetches default set)
    books = await repository.fetchAllBooks();
    // Timeline posts are not fetched from API yet; keep empty list
    timelinePosts = [];
    isLoading = false;
    notifyListeners();
  }

  // Retained for compatibility; calls internal load method
Future<void> loadData(BuildContext context) async => _loadData(context);
}
