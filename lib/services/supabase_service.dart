// SupabaseService: handles real Supabase interactions only – no mock data.
// Mock book data removed – books are fetched from external APIs via BookRepository.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/user_profile.dart';
import '../models/post.dart';

class SupabaseService extends ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  SupabaseClient? _client;

  // ----- Initialization ----------------------------------------------------
  Future<void> initialize({String? url, String? anonKey}) async {
    if (url != null &&
        anonKey != null &&
        url.isNotEmpty &&
        anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(url: url, anonKey: anonKey);
        _client = Supabase.instance.client;
        _isInitialized = true;
        debugPrint('Supabase initialized successfully.');
      } catch (e) {
        debugPrint('Supabase initialization failed: $e');
      }
    } else {
      debugPrint(
        'Supabase credentials not provided – service remains uninitialized.',
      );
    }
  }

  // ----- Helper -----------------------------------------------------------
  // Returns the current authenticated user ID, or an empty string if not logged in.
  String get activeProfileId => _client?.auth.currentUser?.id ?? '';

  // ----- BOOK QUERIES -----------------------------------------------------
  // NOTE: Book data is now fetched via external APIs, not stored in Supabase.
  // These methods are kept for compatibility but return empty lists.
  Future<List<Book>> fetchBooks() async {
    return [];
  }

  // Updated to avoid querying non-existent 'books' table.
  Future<List<Book>> searchBooks(String query) async {
    if (query.isEmpty) return fetchBooks();
    // No direct books table; return empty list.
    return [];
  }

  Future<List<Book>> fetchBooksByGenre(String genre) async {
    // No direct books table; return empty list.
    return [];
  }

  Future<List<Post>> fetchTimelinePosts() async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('posts')
            .select('*, profiles(username, avatar_url)')
            .order('created_at', ascending: false);
        return (response as List).map((json) => Post.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error fetching timeline posts in Supabase: $e');
      }
    }
    return [];
  }

  // Removed duplicate fetchBooksByGenre (books table no longer exists).

  // Duplicate fetchTimelinePosts removed; retained version earlier.

  // ----- USER PROFILE ------------------------------------------------------
  Future<UserProfile> fetchUserProfile(String profileId) async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('profiles')
            .select()
            .eq('id', profileId)
            .single();
        return UserProfile.fromJson(response);
      } catch (e) {
        debugPrint('Error fetching user profile in Supabase: $e');
      }
    }
    // Return a minimal placeholder profile if not initialized.
    return UserProfile(
      id: profileId,
      username: 'unknown',
      avatarUrl: '',
      bio: '',
      followersCount: 0,
      followingCount: 0,
      readCount: 0,
    );
  }

  // ----- USER COLLECTIONS & FAVORITES --------------------------------------
  // Updated to fetch only book IDs; actual Book details are retrieved via external APIs.
  Future<List<Book>> fetchUserCollections(String profileId) async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('collections')
            .select('book_id')
            .eq('profile_id', profileId);
        // Currently returning empty list as Book objects are fetched elsewhere.
        return [];
      } catch (e) {
        debugPrint('Error fetching user collection in Supabase: $e');
      }
    }
    return [];
  }

  Future<List<Book>> fetchUserFavorites(String profileId) async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('favorites')
            .select('book_id')
            .eq('profile_id', profileId);
        // Currently returning empty list as Book objects are fetched elsewhere.
        return [];
      } catch (e) {
        debugPrint('Error fetching user favorites in Supabase: $e');
      }
    }
    return [];
  }

  // 該当箇所（105行目付近から始まるメソッド）をこれに差し替えてください
  Future<List<Post>> fetchUserPosts(String uid) async {
    if (!_isInitialized || _client == null) return [];

    try {
      // 1. Supabaseからは「レビューデータ」と「本のID（book_id）」だけを取得する
      final response = await _client!
          .from('posts')
          .select('*, profiles(username, avatar_url)')
          .eq(
            'profile_id',
            uid,
          ); // ※既存のcreatePostが'profile_id'で保存しているため、ここもprofile_idに合わせます

      // 2. 返ってきた生データを、正しくPostモデルの形に変換する
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      debugPrint('fetchUserPostsでエラーが発生しました: $e');
      return [];
    }
  }

  // ----- ACTIONS -----------------------------------------------------------
  Future<bool> createPost({
    required String bookId,
    required double rating,
    required String comment,
  }) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty) {
      debugPrint('Cannot create post: no authenticated user.');
      return false;
    }
    if (_isInitialized && _client != null) {
      try {
        await _client!.from('posts').insert({
          'profile_id': profileId,
          'book_id': bookId,
          'rating': rating,
          'comment': comment,
        });
        await _client!.rpc(
          'increment_read_count',
          params: {'user_id': profileId},
        );
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Error inserting post in Supabase: $e');
      }
    }
    debugPrint('Supabase not initialized – post not created.');
    return false;
  }

  Future<bool> toggleFavorite(String bookId) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty) {
      debugPrint('Cannot toggle favorite: no authenticated user.');
      return false;
    }
    if (_isInitialized && _client != null) {
      try {
        // Determine if already favorited
        final favRes = await _client!
            .from('favorites')
            .select('book_id')
            .eq('profile_id', profileId)
            .eq('book_id', bookId);
        final isFav = (favRes as List).isNotEmpty;
        if (isFav) {
          await _client!
              .from('favorites')
              .delete()
              .eq('profile_id', profileId)
              .eq('book_id', bookId);
        } else {
          await _client!.from('favorites').insert({
            'profile_id': profileId,
            'book_id': bookId,
          });
        }
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Error toggling favorite in Supabase: $e');
      }
    }
    debugPrint('Supabase not initialized – favorite not toggled.');
    return false;
  }
}
