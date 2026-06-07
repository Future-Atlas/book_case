import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';

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
    final service = Provider.of<SupabaseService>(context, listen: false);
    final fetchedBooks = await service.fetchBooks();
    final fetchedTimeline = await service.fetchTimelinePosts();
    books = fetchedBooks;
    timelinePosts = fetchedTimeline;
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadData(BuildContext context) async => _loadData(context);
}
