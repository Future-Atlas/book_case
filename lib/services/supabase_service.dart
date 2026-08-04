// SupabaseService: handles real Supabase interactions only – no mock data.
// Mock book data removed – books are fetched from external APIs via BookRepository.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';
import '../models/user_profile.dart';
import '../models/post.dart';
import 'legal_document_versions.dart';

class SupabaseService extends ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _authStateSubscription;
  String? _redirectUrl;
  bool? _hasCurrentLegalConsentCache;
  String? _cachedConsentUserId;

  // ----- Initialization ----------------------------------------------------
  Future<void> initialize({
    String? url,
    String? anonKey,
    String? redirectUrl,
  }) async {
    if (url != null &&
        anonKey != null &&
        url.isNotEmpty &&
        anonKey.isNotEmpty) {
      try {
        _redirectUrl = redirectUrl?.trim().isNotEmpty == true
            ? redirectUrl!.trim()
            : null;

        await Supabase.initialize(url: url, publishableKey: anonKey);
        _client = Supabase.instance.client;
        _isInitialized = true;

        _authStateSubscription?.cancel();
        _authStateSubscription = _client!.auth.onAuthStateChange.listen((evt) {
          final user = evt.session?.user;
          if (_cachedConsentUserId != user?.id) {
            _cachedConsentUserId = user?.id;
            _hasCurrentLegalConsentCache = null;
          }
          if (user != null) {
            _ensureProfile(userId: user.id);
          }
          notifyListeners();
        });

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

  bool get isAuthenticated => _client?.auth.currentSession != null;

  User? get currentUser => _client?.auth.currentUser;

  // ----- AUTH -------------------------------------------------------------
  Future<String?> sendMagicLink({required String email}) async {
    if (!_isInitialized || _client == null) {
      return 'Supabaseが初期化されていません。';
    }

    try {
      await _client!.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        emailRedirectTo: _redirectUrl,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'マジックリンク送信に失敗しました: $e';
    }
  }

  Future<String?> signInWithGoogle() async {
    if (!_isInitialized || _client == null) {
      return 'Supabaseが初期化されていません。';
    }

    try {
      final started = await _client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : _redirectUrl,
        queryParams: const {'prompt': 'select_account'},
      );

      if (!started) {
        return 'Googleログインを開始できませんでした。';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Googleログインに失敗しました: $e';
    }
  }

  Future<String?> signInWithX() async {
    if (!_isInitialized || _client == null) {
      return 'Supabaseが初期化されていません。';
    }

    try {
      final started = await _client!.auth.signInWithOAuth(
        OAuthProvider.x,
        redirectTo: kIsWeb ? null : _redirectUrl,
      );

      if (!started) {
        return 'Xログインを開始できませんでした。';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Xログインに失敗しました: $e';
    }
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized || _client == null) {
      return 'Supabaseが初期化されていません。';
    }

    try {
      final response = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        await _ensureProfile(userId: user.id, preferredUsername: null);
      }
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'ログインに失敗しました: $e';
    }
  }

  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    String? username,
  }) async {
    if (!_isInitialized || _client == null) {
      return 'Supabaseが初期化されていません。';
    }

    try {
      final response = await _client!.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        await _ensureProfile(userId: user.id, preferredUsername: username);
      }
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return '新規登録に失敗しました: $e';
    }
  }

  Future<void> signOut() async {
    if (!_isInitialized || _client == null) return;
    try {
      await _client!.auth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<void> ensureCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return;
    await _ensureProfile(userId: user.id);
  }

  Future<void> _ensureProfile({
    required String userId,
    String? preferredUsername,
  }) async {
    if (!_isInitialized || _client == null) return;

    final generatedUsername = preferredUsername?.trim().isNotEmpty == true
        ? preferredUsername!.trim()
        : _anonymousUsername(userId);

    try {
      final existing = await _client!
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (existing != null) return;

      await _client!.from('profiles').insert({
        'id': userId,
        'username': generatedUsername,
        'avatar_url': '',
        'bio': '',
      });
    } catch (e) {
      debugPrint('Error ensuring profile: $e');
    }
  }

  String _anonymousUsername(String userId) {
    final compactId = userId.replaceAll('-', '');
    final suffix = compactId.length >= 10
        ? compactId.substring(0, 10)
        : compactId;
    return 'reader_$suffix';
  }

  Future<bool> hasCurrentLegalConsent({bool forceRefresh = false}) async {
    final userId = activeProfileId;
    if (!_isInitialized || _client == null || userId.isEmpty) return false;
    if (!forceRefresh &&
        _cachedConsentUserId == userId &&
        _hasCurrentLegalConsentCache != null) {
      return _hasCurrentLegalConsentCache!;
    }

    try {
      final consent = await _client!
          .from('legal_consents')
          .select('id')
          .eq('profile_id', userId)
          .eq('bundle_version', LegalDocumentVersions.bundle)
          .maybeSingle();
      _cachedConsentUserId = userId;
      _hasCurrentLegalConsentCache = consent != null;
      return consent != null;
    } catch (e) {
      debugPrint('Error checking legal consent: $e');
      return false;
    }
  }

  Future<String?> acceptCurrentLegalDocuments() async {
    final user = currentUser;
    if (!_isInitialized || _client == null || user == null) {
      return 'ログイン状態を確認できませんでした。';
    }

    try {
      await _ensureProfile(userId: user.id);
      final provider = user.appMetadata['provider']?.toString();
      await _client!.from('legal_consents').insert({
        'profile_id': user.id,
        'bundle_version': LegalDocumentVersions.bundle,
        'terms_version': LegalDocumentVersions.terms,
        'privacy_version': LegalDocumentVersions.privacy,
        'community_guidelines_version':
            LegalDocumentVersions.communityGuidelines,
        'infringement_policy_version': LegalDocumentVersions.infringementPolicy,
        'external_transmission_version':
            LegalDocumentVersions.externalTransmission,
        'auth_provider': provider,
      });
      _cachedConsentUserId = user.id;
      _hasCurrentLegalConsentCache = true;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error saving legal consent: $e');
      return '同意内容を保存できませんでした。データベース更新後にもう一度お試しください。';
    }
  }

  Future<String?> submitContactRequest({
    required String email,
    required String category,
    required String subject,
    required String message,
  }) async {
    if (!_isInitialized || _client == null) {
      return 'お問い合わせ機能を初期化できませんでした。';
    }

    try {
      final profileId = activeProfileId;
      await _client!.from('contact_requests').insert({
        'profile_id': profileId.isEmpty ? null : profileId,
        'email': email.trim(),
        'category': category,
        'subject': subject.trim(),
        'message': message.trim(),
      });
      return null;
    } catch (e) {
      debugPrint('Error submitting contact request: $e');
      return 'お問い合わせを送信できませんでした。データベース更新後にもう一度お試しください。';
    }
  }

  Future<String?> deleteCurrentAccount() async {
    if (!_isInitialized || _client == null || !isAuthenticated) {
      return 'ログイン状態を確認できませんでした。';
    }

    try {
      final response = await _client!.functions.invoke(
        'delete-account',
        body: const {'confirmation': true},
      );
      if (response.status < 200 || response.status >= 300) {
        return '退会処理に失敗しました。お問い合わせフォームからご連絡ください。';
      }
      await signOut();
      _cachedConsentUserId = null;
      _hasCurrentLegalConsentCache = null;
      return null;
    } on FunctionException catch (e) {
      debugPrint('Delete account function error: $e');
      return '退会処理に失敗しました。Edge Functionの配備状況を確認してください。';
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return '退会処理に失敗しました。もう一度お試しください。';
    }
  }

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
        await _client!
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
        await _client!
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

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
