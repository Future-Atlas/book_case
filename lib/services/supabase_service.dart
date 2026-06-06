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

  // Local Mock Data for Fallback/Demo purposes
  final List<Book> _mockBooks = [
    Book(
      id: 'b1111111-1111-1111-1111-111111111111',
      title: 'Project Hail Mary',
      author: 'Andy Weir',
      coverUrl: 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&w=400&q=80',
      genre: '洋書',
      description: 'A lone astronaut must save the earth from an extinction-level event.',
      ratingAvg: 4.8,
    ),
    Book(
      id: 'b2222222-2222-2222-2222-222222222222',
      title: 'Dune',
      author: 'Frank Herbert',
      coverUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&w=400&q=80',
      genre: '洋書',
      description: 'Set on the desert planet Arrakis, Dune is the story of the boy Paul Atreides.',
      ratingAvg: 4.5,
    ),
    Book(
      id: 'b3333333-3333-3333-3333-333333333333',
      title: 'Klara and the Sun',
      author: 'Kazuo Ishiguro',
      coverUrl: 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&w=400&q=80',
      genre: '洋書',
      description: 'The story of Klara, an Artificial Friend with outstanding observational qualities.',
      ratingAvg: 4.2,
    ),
    Book(
      id: 'b4444444-4444-4444-4444-444444444444',
      title: '銀河鉄道の夜',
      author: '宮沢賢治',
      coverUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=400&q=80',
      genre: '人気',
      description: '貧しい少年ジョバンニが、親友カムパネルラと銀河鉄道の旅をする幻想小説。',
      ratingAvg: 4.7,
    ),
    Book(
      id: 'b5555555-5555-5555-5555-555555555555',
      title: '人間失格',
      author: '太宰治',
      coverUrl: 'https://images.unsplash.com/photo-1495640388908-05fa85288e61?auto=format&fit=crop&w=400&q=80',
      genre: '人気',
      description: '「恥の多い生涯を送って来ました。」で始まる太宰治の自伝的小説。',
      ratingAvg: 4.4,
    ),
    Book(
      id: 'b6666666-6666-6666-6666-666666666666',
      title: 'ノルウェイの森',
      author: '村上春樹',
      coverUrl: 'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?auto=format&fit=crop&w=400&q=80',
      genre: '人気',
      description: '主人公のワタナベが、直子と緑という二人の少女の間で揺れる恋と喪失の物語。',
      ratingAvg: 4.6,
    ),
    Book(
      id: 'b7777777-7777-7777-7777-777777777777',
      title: 'こころ',
      author: '夏目漱石',
      coverUrl: 'https://images.unsplash.com/photo-1476275466078-4007374efbbe?auto=format&fit=crop&w=400&q=80',
      genre: '文学',
      description: '「先生」と私、そして先生の遺書を通じて描かれる人間のエゴイズムと倫理。',
      ratingAvg: 4.5,
    )
  ];

  late UserProfile _mockProfile;
  final List<Post> _mockPosts = [];
  final List<String> _mockFavorites = []; // Book IDs
  final List<String> _mockCollections = []; // Book IDs

  // Initialize client
  Future<void> initialize({String? url, String? anonKey}) async {
    // Set up mock profile first
    _mockProfile = UserProfile(
      id: 'd3b07384-d113-4ec5-a587-f3e098a58f4a',
      username: 'ryu_booklover',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
      bio: '本を読むのが大好きなソフトウェアエンジニア。最近はSF小説とミステリーを多く読んでいます。',
      followersCount: 128,
      followingCount: 94,
      readCount: 42,
    );


    // Populate mock posts
    _mockPosts.addAll([
      Post(
        id: 'e1111111-1111-1111-1111-111111111111',
        profileId: _mockProfile.id,
        bookId: 'b1111111-1111-1111-1111-111111111111',
        rating: 5.0,
        comment: 'SF小説の最高傑作！最初から最後まで興奮が収まらなかった。キャラクターの掛け合いも最高。',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        username: _mockProfile.username,
        userAvatarUrl: _mockProfile.avatarUrl,
        bookTitle: 'Project Hail Mary',
        bookAuthor: 'Andy Weir',
        bookCoverUrl: 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&w=400&q=80',
      ),
      Post(
        id: 'e2222222-2222-2222-2222-222222222222',
        profileId: _mockProfile.id,
        bookId: 'b4444444-4444-4444-4444-444444444444',
        rating: 4.5,
        comment: '読むたびに新しい発見がある素晴らしい本。言葉の響きが美しく、切ないストーリーに胸が締め付けられます。',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        username: _mockProfile.username,
        userAvatarUrl: _mockProfile.avatarUrl,
        bookTitle: '銀河鉄道の夜',
        bookAuthor: '宮沢賢治',
        bookCoverUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=400&q=80',
      ),
    ]);
    _mockCollections.addAll([
      'b1111111-1111-1111-1111-111111111111',
      'b2222222-2222-2222-2222-222222222222',
      'b3333333-3333-3333-3333-333333333333',
      'b4444444-4444-4444-4444-444444444444',
      'b5555555-5555-5555-5555-555555555555',
      'b6666666-6666-6666-6666-666666666666',
    ]);

    _mockFavorites.addAll([
      'b1111111-1111-1111-1111-111111111111',
      'b4444444-4444-4444-4444-444444444444',
      'b6666666-6666-6666-6666-666666666666',
    ]);

    if (url != null && anonKey != null && url.isNotEmpty && anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(url: url, anonKey: anonKey);
        _client = Supabase.instance.client;
        _isInitialized = true;
        debugPrint('Supabase initialized successfully.');
      } catch (e) {
        debugPrint('Supabase failed to initialize: $e. Using Mock Data fallback.');
      }
    } else {
      debugPrint('No Supabase credentials provided. Using Mock Data.');
    }
  }

  // Get current user profile (using first mock profile as active user)
  String get activeProfileId => _mockProfile.id;

  // --- BOOK QUERIES ---

  Future<List<Book>> fetchBooks() async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!.from('books').select().order('created_at');
        return (response as List).map((json) => Book.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error fetching books from Supabase: $e');
      }
    }
    return List.from(_mockBooks);
  }

  Future<List<Book>> searchBooks(String query) async {
    if (query.isEmpty) return fetchBooks();
    
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('books')
            .select()
            .or('title.ilike.%$query%,author.ilike.%$query%,genre.ilike.%$query%')
            .order('created_at');
        return (response as List).map((json) => Book.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error searching books in Supabase: $e');
      }
    }
    
    final lowerQuery = query.toLowerCase();
    return _mockBooks.where((book) =>
        book.title.toLowerCase().contains(lowerQuery) ||
        book.author.toLowerCase().contains(lowerQuery) ||
        book.genre.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  Future<List<Book>> fetchBooksByGenre(String genre) async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('books')
            .select()
            .eq('genre', genre)
            .order('created_at');
        return (response as List).map((json) => Book.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error fetching books by genre in Supabase: $e');
      }
    }
    return _mockBooks.where((book) => book.genre == genre).toList();
  }

  // --- POST / TIMELINE QUERIES ---

  Future<List<Post>> fetchTimelinePosts() async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('posts')
            .select('*, profiles(username, avatar_url), books(title, author, cover_url)')
            .order('created_at', ascending: false);
        return (response as List).map((json) => Post.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error fetching timeline posts in Supabase: $e');
      }
    }
    // Sort mock posts by date descending
    _mockPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.from(_mockPosts);
  }

  // --- USER PROFILE & DETAILS ---

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
    return _mockProfile;
  }

  Future<List<Post>> fetchUserPosts(String profileId) async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('posts')
            .select('*, profiles(username, avatar_url), books(title, author, cover_url)')
            .eq('profile_id', profileId)
            .order('created_at', ascending: false);
        return (response as List).map((json) => Post.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error fetching user posts in Supabase: $e');
      }
    }
    return _mockPosts.where((post) => post.profileId == profileId).toList();
  }

  Future<List<Book>> fetchUserCollections(String profileId) async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('collections')
            .select('book_id, books(*)')
            .eq('profile_id', profileId);
        return (response as List)
            .map((item) => Book.fromJson(item['books']))
            .toList();
      } catch (e) {
        debugPrint('Error fetching user collection in Supabase: $e');
      }
    }
    // Fallback: match mock IDs
    return _mockBooks.where((book) => _mockCollections.contains(book.id)).toList();
  }

  Future<List<Book>> fetchUserFavorites(String profileId) async {
    if (_isInitialized && _client != null) {
      try {
        final response = await _client!
            .from('favorites')
            .select('book_id, books(*)')
            .eq('profile_id', profileId);
        return (response as List)
            .map((item) => Book.fromJson(item['books']))
            .toList();
      } catch (e) {
        debugPrint('Error fetching user favorites in Supabase: $e');
      }
    }
    // Fallback: match mock IDs
    return _mockBooks.where((book) => _mockFavorites.contains(book.id)).toList();
  }

  // --- ACTIONS ---

  Future<bool> createPost({
    required String bookId,
    required double rating,
    required String comment,
  }) async {
    final profileId = activeProfileId;
    
    if (_isInitialized && _client != null) {
      try {
        await _client!.from('posts').insert({
          'profile_id': profileId,
          'book_id': bookId,
          'rating': rating,
          'comment': comment,
        });
        
        // Increment read count on profile
        await _client!.rpc('increment_read_count', params: {'user_id': profileId});
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Error inserting post in Supabase: $e. Falling back to local update.');
      }
    }

    // Local Mock update
    final book = _mockBooks.firstWhere((b) => b.id == bookId, orElse: () => _mockBooks[0]);
    final newPost = Post(
      id: 'p-mock-${DateTime.now().millisecondsSinceEpoch}',
      profileId: profileId,
      bookId: bookId,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
      username: _mockProfile.username,
      userAvatarUrl: _mockProfile.avatarUrl,
      bookTitle: book.title,
      bookAuthor: book.author,
      bookCoverUrl: book.coverUrl,
    );

    _mockPosts.add(newPost);
    
    // Add to collection automatically if not there
    if (!_mockCollections.contains(bookId)) {
      _mockCollections.add(bookId);
    }
    
    notifyListeners();
    return true;
  }

  Future<bool> toggleFavorite(String bookId) async {
    final profileId = activeProfileId;

    if (_isInitialized && _client != null) {
      try {
        final isFav = _mockFavorites.contains(bookId);
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

    if (_mockFavorites.contains(bookId)) {
      _mockFavorites.remove(bookId);
    } else {
      _mockFavorites.add(bookId);
    }
    notifyListeners();
    return true;
  }
}
