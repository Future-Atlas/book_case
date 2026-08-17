// SupabaseService: handles real Supabase interactions only – no mock data.
// Mock book data removed – books are fetched from external APIs via BookRepository.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/rakuten_api.dart';
import '../models/book.dart';
import 'legal_document_versions.dart';
import '../models/user_profile.dart';
import '../models/post.dart';
import '../models/social_models.dart';
import '../models/moderation_models.dart';
import 'content_safety_service.dart';

enum FavoriteToggleResult { added, removed, limitReached, failed }

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
  bool? _hasCompletedRegistrationCache;
  String? _cachedRegistrationUserId;

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
          if (_cachedRegistrationUserId != user?.id) {
            _cachedRegistrationUserId = user?.id;
            _hasCompletedRegistrationCache = null;
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
        emailRedirectTo: _authRedirectUrl(),
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
        redirectTo: _authRedirectUrl(),
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
        redirectTo: _authRedirectUrl(),
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

  Future<String?> signInWithFacebook({bool privacyRecovery = false}) =>
      _signInWithSocialProvider(
        OAuthProvider.facebook,
        label: 'Facebook',
        privacyRecovery: privacyRecovery,
      );

  Future<String?> signInWithApple({bool privacyRecovery = false}) =>
      _signInWithSocialProvider(
        OAuthProvider.apple,
        label: 'Apple',
        privacyRecovery: privacyRecovery,
      );

  Future<String?> signInWithDiscord({bool privacyRecovery = false}) =>
      _signInWithSocialProvider(
        OAuthProvider.discord,
        label: 'Discord',
        privacyRecovery: privacyRecovery,
      );

  Future<String?> _signInWithSocialProvider(
    OAuthProvider provider, {
    required String label,
    bool privacyRecovery = false,
  }) async {
    if (!_isInitialized || _client == null) {
      return 'Supabaseが初期化されていません。';
    }

    try {
      final redirectTo = privacyRecovery
          ? _privacyRecoveryRedirectUrl()
          : _authRedirectUrl();
      final started = await _client!.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
      );
      return started ? null : '$labelログインを開始できませんでした。';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return '$labelログインに失敗しました: $e';
    }
  }

  String? _privacyRecoveryRedirectUrl() {
    final source = _authRedirectUrl();
    if (source == null || source.isEmpty) return null;
    final uri = Uri.tryParse(source);
    if (uri == null) return source;
    return uri
        .replace(
          queryParameters: const {'privacy_password_recovery': '1'},
          fragment: '',
        )
        .toString();
  }

  /// Returns the URL to which Supabase should send the user after auth.
  ///
  /// On web, always use the origin that is currently serving the app. This
  /// prevents a stale Supabase Site URL from sending production users back to
  /// an old Vercel deployment URL. Native apps continue to use the configured
  /// redirect URL.
  String? _authRedirectUrl() {
    if (!kIsWeb) return _redirectUrl;

    final current = Uri.base;
    if (!current.hasScheme || current.host.isEmpty) return _redirectUrl;

    return Uri(
      scheme: current.scheme,
      host: current.host,
      port: current.hasPort ? current.port : null,
      path: '/',
    ).toString();
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
        'user_id': _anonymousUserId(userId),
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

  String _anonymousUserId(String profileId) {
    final compactId = profileId.replaceAll('-', '').toLowerCase();
    final suffix = compactId.length >= 10
        ? compactId.substring(0, 10)
        : compactId;
    return 'reader_$suffix';
  }

  Future<bool> hasCompletedRegistration({bool forceRefresh = false}) async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return false;
    if (!forceRefresh &&
        _cachedRegistrationUserId == profileId &&
        _hasCompletedRegistrationCache != null) {
      return _hasCompletedRegistrationCache!;
    }

    try {
      final profile = await _client!
          .from('profiles')
          .select('user_id, username')
          .eq('id', profileId)
          .maybeSingle();
      final details = await _client!
          .from('account_details')
          .select('profile_id')
          .eq('profile_id', profileId)
          .maybeSingle();
      final completed =
          profile != null &&
          (profile['user_id']?.toString().isNotEmpty ?? false) &&
          (profile['username']?.toString().isNotEmpty ?? false) &&
          details != null;
      _cachedRegistrationUserId = profileId;
      _hasCompletedRegistrationCache = completed;
      return completed;
    } catch (e) {
      debugPrint('Error checking registration status: $e');
      return false;
    }
  }

  Future<bool> hasPrivacyPassword() async {
    if (!_isInitialized || _client == null || !isAuthenticated) return false;
    try {
      final result = await _client!.rpc('has_privacy_password');
      return result == true;
    } catch (e) {
      debugPrint('Error checking privacy password: $e');
      return false;
    }
  }

  Future<bool> requiresGuardianConsent() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return false;
    try {
      final details = await _client!
          .from('account_details')
          .select(
            'birth_date, guardian_consent_declared_at, guardian_consent_terms_version',
          )
          .eq('profile_id', profileId)
          .maybeSingle();
      final birthDate = DateTime.tryParse(
        details?['birth_date']?.toString() ?? '',
      );
      if (birthDate == null || ContentSafetyService.isAtLeast18(birthDate)) {
        return false;
      }
      return details?['guardian_consent_declared_at'] == null ||
          details?['guardian_consent_terms_version'] !=
              LegalDocumentVersions.terms;
    } catch (e) {
      debugPrint('Error checking guardian consent: $e');
      return true;
    }
  }

  Future<String?> declareGuardianConsent() async {
    if (!_isInitialized || _client == null || !isAuthenticated) {
      return 'ログイン状態を確認できませんでした。';
    }
    try {
      await _client!.rpc(
        'declare_guardian_consent',
        params: {'p_terms_version': LegalDocumentVersions.terms},
      );
      return null;
    } catch (e) {
      debugPrint('Error recording guardian consent declaration: $e');
      return '保護者の同意確認を保存できませんでした。データベース更新後に再試行してください。';
    }
  }

  Future<String?> initializePrivacyPassword(String password) async {
    if (!_isInitialized || _client == null || !isAuthenticated) {
      return 'ログイン状態を確認できませんでした。';
    }
    try {
      await _client!.rpc(
        'initialize_privacy_password',
        params: {'p_password': password},
      );
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23514') return 'パスワードの条件を確認してください。';
      return e.message;
    } catch (e) {
      return 'パスワードを保存できませんでした。';
    }
  }

  Future<bool> isPublicUserIdAvailable(String userId) async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return false;

    try {
      final normalized = userId.trim().toLowerCase();
      final existing = await _client!
          .from('profiles')
          .select('id')
          .eq('user_id', normalized)
          .neq('id', profileId)
          .maybeSingle();
      return existing == null;
    } catch (e) {
      debugPrint('Error checking public user ID: $e');
      return false;
    }
  }

  Future<String?> completeRegistration({
    required String fullName,
    required DateTime birthDate,
    required String phoneNumber,
    required String username,
    required String userId,
    required String privacyPassword,
    required bool guardianConsentDeclared,
  }) async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) {
      return 'ログイン状態を確認できませんでした。';
    }

    try {
      await _ensureProfile(userId: profileId);
      await _client!.rpc(
        'complete_registration',
        params: {
          'p_full_name': fullName.trim(),
          'p_birth_date': birthDate.toIso8601String().split('T').first,
          'p_phone_number': _normalizePhoneNumber(phoneNumber),
          'p_username': username.trim(),
          'p_user_id': userId.trim().toLowerCase(),
          'p_privacy_password': privacyPassword,
          'p_guardian_consent': guardianConsentDeclared,
          'p_terms_version': LegalDocumentVersions.terms,
        },
      );
      _cachedRegistrationUserId = profileId;
      _hasCompletedRegistrationCache = true;
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      debugPrint('Registration RPC error: $e');
      if (e.message.contains('REGISTRATION_DENIED')) {
        return 'この登録情報では利用登録できません。心当たりがない場合は、お問い合わせフォームからご連絡ください。';
      }
      if (e.code == '23505') {
        return 'このユーザーIDはすでに使用されています。';
      }
      if (e.message.contains('GUARDIAN_CONSENT_REQUIRED')) {
        return '18歳未満の方は、保護者の同意が必要です。';
      }
      if (e.code == '23514') {
        return '入力内容を確認してください。';
      }
      return '登録情報を保存できませんでした。データベース更新後にもう一度お試しください。';
    } catch (e) {
      debugPrint('Error completing registration: $e');
      return '登録情報を保存できませんでした。もう一度お試しください。';
    }
  }

  String _normalizePhoneNumber(String source) {
    return source.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<Map<String, dynamic>?> fetchCurrentAccountDetails() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return null;

    try {
      return await _client!
          .from('account_details')
          .select(
            'full_name, birth_date, phone_number, phone_verified_at, updated_at',
          )
          .eq('profile_id', profileId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error fetching account details: $e');
      return null;
    }
  }

  /// Users without a verified registration birth date are treated as minors.
  /// This fail-closed behavior also applies to signed-out visitors.
  Future<bool> canViewAdultContent() async {
    if (!isAuthenticated) return false;
    final details = await fetchCurrentAccountDetails();
    final birthDate = DateTime.tryParse(
      details?['birth_date']?.toString() ?? '',
    );
    if (birthDate == null) return false;
    return ContentSafetyService.isAtLeast18(birthDate);
  }

  Future<Map<String, dynamic>?> fetchCurrentSettingsData() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return null;
    try {
      final profile = await _client!
          .from('profiles')
          .select('username, user_id, is_private')
          .eq('id', profileId)
          .single();
      final details = await fetchCurrentAccountDetails();
      return {...profile, ...?details, 'email': currentUser?.email ?? ''};
    } catch (e) {
      debugPrint('Error fetching settings data: $e');
      return null;
    }
  }

  Future<String?> updatePublicProfile({
    required String username,
    required String userId,
    required bool isPrivate,
  }) async {
    if (!_isInitialized || _client == null || !isAuthenticated) {
      return 'ログイン状態を確認できませんでした。';
    }
    try {
      await _client!.rpc(
        'update_public_profile',
        params: {
          'p_username': username.trim(),
          'p_user_id': userId.trim().toLowerCase(),
          'p_is_private': isPrivate,
        },
      );
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'このユーザーIDはすでに使用されています。';
      if (e.code == '23514') return '入力内容を確認してください。';
      return e.message;
    } catch (e) {
      return 'アカウント設定を保存できませんでした。';
    }
  }

  Future<bool> verifyPrivacyPassword(String password) async {
    if (!_isInitialized || _client == null || !isAuthenticated) return false;
    try {
      final result = await _client!.rpc(
        'verify_privacy_password',
        params: {'p_password': password},
      );
      return result == true;
    } catch (e) {
      debugPrint('Error verifying privacy password: $e');
      return false;
    }
  }

  Future<String?> updatePrivateAccountDetails({
    required String password,
    required String fullName,
    required DateTime birthDate,
    required String phoneNumber,
    required String email,
  }) async {
    if (!_isInitialized || _client == null || !isAuthenticated) {
      return 'ログイン状態を確認できませんでした。';
    }
    try {
      final verified = await verifyPrivacyPassword(password);
      if (!verified) return 'パスワードが正しくありません。';

      final normalizedEmail = email.trim();
      if (normalizedEmail != (currentUser?.email ?? '')) {
        await _client!.auth.updateUser(
          UserAttributes(email: normalizedEmail),
          emailRedirectTo: _redirectUrl,
        );
      }
      final updated = await _client!.rpc(
        'update_private_account_details',
        params: {
          'p_password': password,
          'p_full_name': fullName.trim(),
          'p_birth_date': birthDate.toIso8601String().split('T').first,
          'p_phone_number': _normalizePhoneNumber(phoneNumber),
        },
      );
      if (updated != true) return 'パスワードが正しくありません。';
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on PostgrestException catch (e) {
      if (e.code == '28P01') return 'パスワードが正しくありません。';
      if (e.code == '23514') return '入力内容を確認してください。';
      return e.message;
    } catch (e) {
      return 'プライバシー設定を保存できませんでした。';
    }
  }

  Future<String?> changePrivacyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_isInitialized || _client == null || !isAuthenticated) {
      return 'ログイン状態を確認できませんでした。';
    }
    try {
      final changed = await _client!.rpc(
        'change_privacy_password',
        params: {
          'p_current_password': currentPassword,
          'p_new_password': newPassword,
        },
      );
      if (changed != true) return '現在のパスワードが正しくありません。';
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '28P01') return '現在のパスワードが正しくありません。';
      if (e.code == '23514') return '新しいパスワードの条件を確認してください。';
      return e.message;
    } catch (e) {
      return 'パスワードを変更できませんでした。';
    }
  }

  Future<String?> beginPrivacyPasswordRecovery() async {
    if (!_isInitialized || _client == null || !isAuthenticated) {
      return 'ログイン状態を確認できませんでした。';
    }
    try {
      final provider = currentUser?.appMetadata['provider']?.toString() ?? '';
      await _client!.rpc('begin_privacy_password_recovery');
      switch (provider) {
        case 'google':
          return _signInWithSocialProvider(
            OAuthProvider.google,
            label: 'Google',
            privacyRecovery: true,
          );
        case 'twitter':
        case 'x':
          return _signInWithSocialProvider(
            OAuthProvider.x,
            label: 'X',
            privacyRecovery: true,
          );
        case 'facebook':
          return signInWithFacebook(privacyRecovery: true);
        case 'apple':
          return signInWithApple(privacyRecovery: true);
        case 'discord':
          return signInWithDiscord(privacyRecovery: true);
        default:
          return 'このログイン方法では再認証できません。お問い合わせからご連絡ください。';
      }
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return '本人確認を開始できませんでした。';
    }
  }

  Future<String?> resetPrivacyPasswordAfterReauthentication(
    String newPassword,
  ) async {
    if (!_isInitialized || _client == null || !isAuthenticated) {
      return 'ログイン状態を確認できませんでした。';
    }
    try {
      await _client!.rpc(
        'reset_privacy_password_after_reauthentication',
        params: {'p_new_password': newPassword},
      );
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '42501') return '本人確認の有効期限が切れました。もう一度お試しください。';
      if (e.code == '23514') return '新しいパスワードの条件を確認してください。';
      return e.message;
    } catch (e) {
      return 'パスワードを再設定できませんでした。';
    }
  }

  Future<List<UserProfile>> fetchBlockedProfiles() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return [];
    try {
      final response = await _client!
          .from('blocks')
          .select(
            'blocked:profiles!blocks_blocked_id_fkey('
            'id, username, user_id, avatar_url, bio, followers_count, '
            'following_count, read_count, is_private)',
          )
          .eq('blocker_id', profileId)
          .order('created_at', ascending: false);
      return (response as List<dynamic>)
          .map((row) => row['blocked'])
          .whereType<Map<String, dynamic>>()
          .map(UserProfile.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Error fetching blocked profiles: $e');
      return [];
    }
  }

  Future<bool?> fetchCurrentProfilePrivacy() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return null;

    try {
      final profile = await _client!
          .from('profiles')
          .select('is_private')
          .eq('id', profileId)
          .maybeSingle();
      return profile?['is_private'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error fetching profile privacy: $e');
      return null;
    }
  }

  Future<String?> updateCurrentProfilePrivacy({required bool isPrivate}) async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) {
      return 'ログイン状態を確認できませんでした。';
    }

    try {
      await _client!
          .from('profiles')
          .update({'is_private': isPrivate})
          .eq('id', profileId);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error updating profile privacy: $e');
      return '鍵アカウント設定を保存できませんでした。データベース更新後にもう一度お試しください。';
    }
  }

  Future<ProfileRelationship> fetchProfileRelationship(
    String targetProfileId,
  ) async {
    final viewerId = activeProfileId;
    if (!_isInitialized || _client == null || viewerId.isEmpty) {
      return const ProfileRelationship(
        isOwnProfile: false,
        followStatus: FollowRelationshipStatus.none,
        blockedByMe: false,
        blockedEitherDirection: false,
      );
    }
    if (viewerId == targetProfileId) {
      return const ProfileRelationship(
        isOwnProfile: true,
        followStatus: FollowRelationshipStatus.none,
        blockedByMe: false,
        blockedEitherDirection: false,
      );
    }

    try {
      final follow = await _client!
          .from('follows')
          .select('status')
          .eq('follower_id', viewerId)
          .eq('following_id', targetProfileId)
          .maybeSingle();
      final ownBlock = await _client!
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', viewerId)
          .eq('blocked_id', targetProfileId)
          .maybeSingle();
      final blockedBetween = await _client!.rpc(
        'is_blocked_between',
        params: {'first_profile': viewerId, 'second_profile': targetProfileId},
      );

      final rawStatus = follow?['status']?.toString();
      final followStatus = rawStatus == 'accepted'
          ? FollowRelationshipStatus.accepted
          : rawStatus == 'pending'
          ? FollowRelationshipStatus.pending
          : FollowRelationshipStatus.none;
      return ProfileRelationship(
        isOwnProfile: false,
        followStatus: followStatus,
        blockedByMe: ownBlock != null,
        blockedEitherDirection: blockedBetween == true,
      );
    } catch (e) {
      debugPrint('Error fetching profile relationship: $e');
      return const ProfileRelationship(
        isOwnProfile: false,
        followStatus: FollowRelationshipStatus.none,
        blockedByMe: false,
        blockedEitherDirection: false,
      );
    }
  }

  Future<FollowRelationshipStatus?> followProfile(
    String targetProfileId,
  ) async {
    if (!_isInitialized || _client == null || !isAuthenticated) return null;
    try {
      final result = await _client!.rpc(
        'request_follow',
        params: {'target_profile': targetProfileId},
      );
      notifyListeners();
      return result?.toString() == 'accepted'
          ? FollowRelationshipStatus.accepted
          : FollowRelationshipStatus.pending;
    } catch (e) {
      debugPrint('Error following profile: $e');
      return null;
    }
  }

  Future<bool> unfollowProfile(String targetProfileId) async {
    if (!_isInitialized || _client == null || !isAuthenticated) return false;
    try {
      await _client!.rpc(
        'unfollow_profile',
        params: {'target_profile': targetProfileId},
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error unfollowing profile: $e');
      return false;
    }
  }

  Future<bool> respondToFollowRequest({
    required String requesterProfileId,
    required bool approve,
  }) async {
    if (!_isInitialized || _client == null || !isAuthenticated) return false;
    try {
      await _client!.rpc(
        'respond_follow_request',
        params: {'requester_profile': requesterProfileId, 'approve': approve},
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error responding to follow request: $e');
      return false;
    }
  }

  Future<bool> blockProfile(String targetProfileId) async {
    if (!_isInitialized || _client == null || !isAuthenticated) return false;
    try {
      await _client!.rpc(
        'block_profile',
        params: {'target_profile': targetProfileId},
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error blocking profile: $e');
      return false;
    }
  }

  Future<bool> unblockProfile(String targetProfileId) async {
    if (!_isInitialized || _client == null || !isAuthenticated) return false;
    try {
      await _client!.rpc(
        'unblock_profile',
        params: {'target_profile': targetProfileId},
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error unblocking profile: $e');
      return false;
    }
  }

  Future<List<SocialNotification>> fetchNotifications() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return [];

    try {
      final response = await _client!
          .from('notifications')
          .select(
            'id, type, actor_id, post_id, read_at, created_at, '
            'actor:profiles!notifications_actor_id_fkey(username, avatar_url), '
            'post:posts!notifications_post_id_fkey(book_id)',
          )
          .eq('recipient_id', profileId)
          .order('created_at', ascending: false)
          .limit(100);
      final pendingResponse = await _client!
          .from('follows')
          .select('follower_id')
          .eq('following_id', profileId)
          .eq('status', 'pending');
      final pendingActorIds = (pendingResponse as List<dynamic>)
          .map((row) => row['follower_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final notifications = <SocialNotification>[];
      final bookCache = <String, String>{};
      for (final raw in response as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        final actor = row['actor'] as Map<String, dynamic>?;
        final post = row['post'] as Map<String, dynamic>?;
        final rawType = row['type']?.toString();
        final type = rawType == 'reaction'
            ? SocialNotificationType.reaction
            : rawType == 'follow_request'
            ? SocialNotificationType.followRequest
            : SocialNotificationType.follow;
        final actorId = row['actor_id']?.toString() ?? '';
        final bookId = post?['book_id']?.toString();
        String? bookTitle;
        if (bookId != null && bookId.isNotEmpty) {
          bookTitle = bookCache[bookId];
          if (bookTitle == null) {
            final book = await RakutenApi.fetchBookById(bookId);
            bookTitle = book?.title ?? bookId;
            bookCache[bookId] = bookTitle;
          }
        }
        notifications.add(
          SocialNotification(
            id: (row['id'] as num).toInt(),
            type: type,
            actorId: actorId,
            actorUsername: actor?['username']?.toString() ?? 'ユーザー',
            actorAvatarUrl: actor?['avatar_url']?.toString() ?? '',
            postId: row['post_id']?.toString(),
            bookId: bookId,
            bookTitle: bookTitle,
            isRead: row['read_at'] != null,
            followRequestPending:
                type == SocialNotificationType.followRequest &&
                pendingActorIds.contains(actorId),
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        );
      }
      return notifications;
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  Future<int> fetchUnreadNotificationCount() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return 0;
    try {
      final response = await _client!
          .from('notifications')
          .select('id')
          .eq('recipient_id', profileId)
          .isFilter('read_at', null);
      return (response as List<dynamic>).length;
    } catch (e) {
      debugPrint('Error fetching unread notification count: $e');
      return 0;
    }
  }

  Future<void> markNotificationsRead() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) return;
    try {
      await _client!
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', profileId)
          .isFilter('read_at', null);
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking notifications read: $e');
    }
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
      _cachedRegistrationUserId = null;
      _hasCompletedRegistrationCache = null;
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
            .select(
              '*, profiles:profiles!posts_profile_id_fkey(username, avatar_url)',
            )
            .order('created_at', ascending: false);
        final data = response as List<dynamic>;
        final posts = _parsePostsSafely(data);
        final enriched = await _enrichPostsWithBookMetadata(posts);
        return _filterPostsForCurrentViewer(enriched);
      } catch (e) {
        debugPrint('Error fetching timeline posts with profile join: $e');
        try {
          // Fallback: if relation join fails due RLS/schema mismatch, still show posts.
          final fallback = await _client!
              .from('posts')
              .select('*')
              .order('created_at', ascending: false);
          final posts = _parsePostsSafely(fallback as List<dynamic>);
          final enriched = await _enrichPostsWithBookMetadata(posts);
          return _filterPostsForCurrentViewer(enriched);
        } catch (fallbackError) {
          debugPrint('Error fetching timeline posts fallback: $fallbackError');
        }
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
      userId: '',
      avatarUrl: '',
      bio: '',
      followersCount: 0,
      followingCount: 0,
      readCount: 0,
      isPrivate: false,
    );
  }

  // ----- USER COLLECTIONS & FAVORITES --------------------------------------
  // Updated to fetch only book IDs; actual Book details are retrieved via external APIs.
  Future<List<Book>> fetchUserCollections(String profileId) async {
    if (_isInitialized && _client != null) {
      try {
        // A posted review is the source of truth for a completed book. Ordering
        // by the newest post first also defines the bookshelf display order.
        final postRes = await _client!
            .from('posts')
            .select('book_id, created_at')
            .eq('profile_id', profileId)
            .order('created_at', ascending: false);

        final bookIds = <String>[];
        final seenBookIds = <String>{};
        for (final row in (postRes as List<dynamic>)) {
          final id = (row['book_id'] ?? '').toString().trim();
          if (id.isNotEmpty && seenBookIds.add(id)) bookIds.add(id);
        }

        if (bookIds.isEmpty) return [];
        return _resolveBooksByIds(bookIds);
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
            .select('book_id, created_at')
            .eq('profile_id', profileId)
            .order('created_at', ascending: false)
            .limit(12);
        final bookIds = (response as List<dynamic>)
            .map((row) => (row['book_id'] ?? '').toString().trim())
            .where((id) => id.isNotEmpty)
            .toList();
        return _resolveBooksByIds(bookIds);
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
          .select(
            '*, profiles:profiles!posts_profile_id_fkey(username, avatar_url)',
          )
          .eq('profile_id', uid)
          .order('created_at', ascending: false);

      // 2. 返ってきた生データを、正しくPostモデルの形に変換する
      final List<dynamic> data = response as List<dynamic>;
      final posts = _parsePostsSafely(data);
      final enriched = await _enrichPostsWithBookMetadata(posts);
      return _filterPostsForCurrentViewer(enriched);
    } catch (e) {
      debugPrint('fetchUserPostsで結合取得エラーが発生しました: $e');
      try {
        final fallback = await _client!
            .from('posts')
            .select('*')
            .eq('profile_id', uid)
            .order('created_at', ascending: false);
        final posts = _parsePostsSafely(fallback as List<dynamic>);
        final enriched = await _enrichPostsWithBookMetadata(posts);
        return _filterPostsForCurrentViewer(enriched);
      } catch (fallbackError) {
        debugPrint('fetchUserPostsフォールバック取得エラー: $fallbackError');
        return [];
      }
    }
  }

  List<Post> _parsePostsSafely(List<dynamic> data) {
    final posts = <Post>[];
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        posts.add(Post.fromJson(raw));
      } catch (e) {
        debugPrint('Skipping malformed post row: $e');
      }
    }
    return posts;
  }

  Future<List<Post>> _enrichPostsWithBookMetadata(List<Post> posts) async {
    if (posts.isEmpty) return posts;

    final cache = <String, Book?>{};

    Future<Book?> getBook(String bookId) async {
      if (cache.containsKey(bookId)) return cache[bookId];
      final found = await RakutenApi.fetchBookById(bookId);
      cache[bookId] = found;
      return found;
    }

    final enriched = <Post>[];
    for (final post in posts) {
      final resolved = await getBook(post.bookId);
      if (resolved == null) {
        enriched.add(post);
        continue;
      }

      enriched.add(
        post.copyWith(
          bookTitle: post.bookTitle.trim().isNotEmpty
              ? post.bookTitle
              : resolved.title,
          bookAuthor: post.bookAuthor.trim().isNotEmpty
              ? post.bookAuthor
              : resolved.author,
          bookCoverUrl: resolved.coverUrl,
        ),
      );
    }
    return _attachReactionState(enriched);
  }

  Future<List<Post>> _filterPostsForCurrentViewer(List<Post> posts) async {
    if (await canViewAdultContent()) return posts;
    return posts
        .where((post) {
          return !post.isAgeRestricted &&
              !ContentSafetyService.containsAdultContentTerms([
                post.bookTitle,
                post.bookAuthor,
                post.comment,
              ]);
        })
        .toList(growable: false);
  }

  Future<List<Post>> _attachReactionState(List<Post> posts) async {
    if (posts.isEmpty || !_isInitialized || _client == null) return posts;

    try {
      final postIds = posts.map((post) => post.id).toList();
      final response = await _client!
          .from('post_reactions')
          .select('post_id, profile_id, reaction_type')
          .inFilter('post_id', postIds);
      final counts = <String, Map<PostReactionType, int>>{};
      final currentReactions = <String, PostReactionType>{};
      final currentProfileId = activeProfileId;
      for (final raw in response as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        final postId = row['post_id']?.toString() ?? '';
        if (postId.isEmpty) continue;
        final reaction =
            PostReactionType.fromDatabase(row['reaction_type']?.toString()) ??
            PostReactionType.like;
        final postCounts = counts.putIfAbsent(postId, () => {});
        postCounts[reaction] = (postCounts[reaction] ?? 0) + 1;
        if (row['profile_id']?.toString() == currentProfileId) {
          currentReactions[postId] = reaction;
        }
      }
      return posts
          .map(
            (post) => post.copyWith(
              reactionCounts: counts[post.id] ?? const {},
              currentUserReaction: currentReactions[post.id],
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error attaching reaction state: $e');
      return posts;
    }
  }

  Future<List<Book>> _resolveBooksByIds(List<String> bookIds) async {
    if (bookIds.isEmpty) return [];

    final results = await Future.wait(
      bookIds.map((id) => RakutenApi.fetchBookById(id)),
    );

    final books = <Book>[];
    for (var i = 0; i < bookIds.length; i++) {
      final id = bookIds[i];
      final resolved = results[i];
      if (resolved != null) {
        books.add(resolved);
        continue;
      }

      // Keep unresolved items visible in collections instead of dropping them.
      books.add(
        Book(
          id: id,
          title: id,
          author: '著者情報なし',
          publisher: '',
          pubDate: '',
          isbn: id,
          coverUrl: '',
          ratingAvg: 0,
          genre: '',
          description: '書誌情報を取得できませんでした。',
        ),
      );
    }
    return books;
  }

  Future<void> _upsertReadCollection({
    required String profileId,
    required String bookId,
  }) async {
    await _client!.from('collections').upsert({
      'profile_id': profileId,
      'book_id': bookId,
      'status': 'read',
    }, onConflict: 'profile_id,book_id');
  }

  // ----- ACTIONS -----------------------------------------------------------
  Future<bool> setPostReaction(String postId, PostReactionType reaction) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty || !_isInitialized || _client == null) return false;

    try {
      final existing = await _client!
          .from('post_reactions')
          .select('reaction_type')
          .eq('post_id', postId)
          .eq('profile_id', profileId)
          .maybeSingle();
      if (existing?['reaction_type']?.toString() == reaction.databaseValue) {
        await _client!
            .from('post_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('profile_id', profileId);
      } else {
        await _client!.from('post_reactions').upsert({
          'post_id': postId,
          'profile_id': profileId,
          'reaction_type': reaction.databaseValue,
        }, onConflict: 'post_id,profile_id');
      }
      return true;
    } catch (e) {
      debugPrint('Error setting post reaction: $e');
      return false;
    }
  }

  Future<bool> submitPostReport({
    required String postId,
    required ReportCategory category,
    String details = '',
  }) async {
    if (!_isInitialized || _client == null || !isAuthenticated) return false;
    try {
      await _client!.rpc(
        'submit_post_report',
        params: {
          'target_post': postId,
          'report_category': category.databaseValue,
          'report_details': details.trim().isEmpty ? null : details.trim(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error submitting post report: $e');
      return false;
    }
  }

  Future<bool> isCurrentUserAdmin() async {
    if (!_isInitialized || _client == null || !isAuthenticated) return false;
    try {
      return await _client!.rpc('is_current_user_admin') == true;
    } catch (e) {
      debugPrint('Error checking administrator access: $e');
      return false;
    }
  }

  Future<AccountSuspensionStatus> fetchCurrentAccountSuspension() async {
    final profileId = activeProfileId;
    if (!_isInitialized || _client == null || profileId.isEmpty) {
      return const AccountSuspensionStatus(
        isSuspended: false,
        reason: '',
        suspendedAt: null,
      );
    }
    try {
      final profile = await _client!
          .from('profiles')
          .select('is_suspended')
          .eq('id', profileId)
          .single();
      final suspension = await _client!
          .from('account_suspensions')
          .select('reason, suspended_at')
          .eq('profile_id', profileId)
          .maybeSingle();
      return AccountSuspensionStatus(
        isSuspended: profile['is_suspended'] == true,
        reason: suspension?['reason']?.toString() ?? '',
        suspendedAt: DateTime.tryParse(
          suspension?['suspended_at']?.toString() ?? '',
        ),
      );
    } catch (e) {
      debugPrint('Error fetching account suspension: $e');
      return const AccountSuspensionStatus(
        isSuspended: false,
        reason: '',
        suspendedAt: null,
      );
    }
  }

  Future<List<ModerationReport>> fetchModerationReports() async {
    if (!await isCurrentUserAdmin() || _client == null) return [];
    try {
      final response = await _client!
          .from('moderation_reports')
          .select(
            'id, post_id, category, details, status, resolution, created_at, '
            'post_snapshot, '
            'reporter:profiles!moderation_reports_reporter_id_fkey(username), '
            'reported:profiles!moderation_reports_reported_profile_id_fkey('
            'id, username, is_suspended)',
          )
          .order('created_at', ascending: false)
          .limit(200);

      return (response as List<dynamic>).map((raw) {
        final row = raw as Map<String, dynamic>;
        final reporter = row['reporter'] as Map<String, dynamic>?;
        final reported = row['reported'] as Map<String, dynamic>?;
        final snapshot = row['post_snapshot'] as Map<String, dynamic>? ?? {};
        return ModerationReport(
          id: (row['id'] as num).toInt(),
          reporterUsername: reporter?['username']?.toString() ?? '退会済みユーザー',
          reportedProfileId:
              reported?['id']?.toString() ??
              snapshot['profile_id']?.toString() ??
              '',
          reportedUsername: reported?['username']?.toString() ?? '退会済みユーザー',
          reportedAccountSuspended: reported?['is_suspended'] == true,
          postId: row['post_id']?.toString(),
          bookId: snapshot['book_id']?.toString() ?? '',
          review: snapshot['review']?.toString() ?? '',
          category: ReportCategory.fromDatabase(row['category']?.toString()),
          details: row['details']?.toString() ?? '',
          status: row['status']?.toString() ?? 'open',
          resolution: row['resolution']?.toString() ?? '',
          createdAt:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching moderation reports: $e');
      return [];
    }
  }

  Future<bool> adminResolveReport(int reportId) async {
    if (!_isInitialized || _client == null) return false;
    try {
      await _client!.rpc(
        'admin_resolve_report',
        params: {'target_report': reportId, 'resolution_note': 'dismissed'},
      );
      return true;
    } catch (e) {
      debugPrint('Error resolving report: $e');
      return false;
    }
  }

  Future<bool> adminDeleteReportedPost(int reportId) async {
    if (!_isInitialized || _client == null) return false;
    try {
      await _client!.rpc(
        'admin_delete_reported_post',
        params: {'target_report': reportId},
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting reported post: $e');
      return false;
    }
  }

  Future<bool> adminSetAccountSuspension({
    required String profileId,
    required bool suspended,
    String reason = '',
  }) async {
    if (!_isInitialized || _client == null || profileId.isEmpty) return false;
    try {
      await _client!.rpc(
        'admin_set_account_suspension',
        params: {
          'target_profile': profileId,
          'suspend': suspended,
          'reason': reason.trim().isEmpty ? null : reason.trim(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error changing account suspension: $e');
      return false;
    }
  }

  Future<bool> adminDeleteAccount({
    required String profileId,
    required String reason,
  }) async {
    if (!_isInitialized ||
        _client == null ||
        !isAuthenticated ||
        profileId.isEmpty) {
      return false;
    }
    try {
      final response = await _client!.functions.invoke(
        'admin-delete-account',
        body: {
          'targetProfileId': profileId,
          'reason': reason.trim(),
          'confirmation': 'DELETE',
        },
      );
      if (response.status < 200 || response.status >= 300) return false;
      notifyListeners();
      return true;
    } on FunctionException catch (e) {
      debugPrint('Admin delete account function error: $e');
      return false;
    } catch (e) {
      debugPrint('Error deleting account as administrator: $e');
      return false;
    }
  }

  Future<bool> markBookAsRead({required String bookId}) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty) {
      debugPrint('Cannot mark book as read: no authenticated user.');
      return false;
    }
    if (_isInitialized && _client != null) {
      try {
        await _upsertReadCollection(profileId: profileId, bookId: bookId);
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Error marking book as read in Supabase: $e');
      }
    }
    debugPrint('Supabase not initialized – collection not updated.');
    return false;
  }

  Future<bool> isBookReadByCurrentUser({required String bookId}) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty || !_isInitialized || _client == null) {
      return false;
    }

    try {
      final collectionRes = await _client!
          .from('collections')
          .select('book_id')
          .eq('profile_id', profileId)
          .eq('book_id', bookId)
          .eq('status', 'read')
          .limit(1);

      if ((collectionRes as List<dynamic>).isNotEmpty) {
        return true;
      }

      // Fallback for legacy data where read books may exist only as posts.
      final postRes = await _client!
          .from('posts')
          .select('book_id')
          .eq('profile_id', profileId)
          .eq('book_id', bookId)
          .limit(1);

      return (postRes as List<dynamic>).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking read status in Supabase: $e');
      return false;
    }
  }

  Future<bool> createPost({
    required Book book,
    required double rating,
    required String comment,
    required bool isSpoiler,
  }) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty) {
      debugPrint('Cannot create post: no authenticated user.');
      return false;
    }
    final isAgeRestricted =
        ContentSafetyService.isAdultBook(book) ||
        ContentSafetyService.containsAdultContentTerms([comment]);
    if (isAgeRestricted && !await canViewAdultContent()) {
      debugPrint('Cannot create an age-restricted post for a minor.');
      return false;
    }
    if (_isInitialized && _client != null) {
      try {
        await _client!.from('posts').insert({
          'profile_id': profileId,
          'book_id': book.id,
          'book_title': book.title,
          'book_author': book.author,
          'book_publisher': book.publisher,
          'book_description': book.description,
          'is_age_restricted': isAgeRestricted,
          'rating': rating,
          'comment': comment,
          'is_spoiler': isSpoiler,
        });

        // Any completed post is also tracked in collections as 'read'.
        await _upsertReadCollection(profileId: profileId, bookId: book.id);

        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Error inserting post in Supabase: $e');
      }
    }
    debugPrint('Supabase not initialized – post not created.');
    return false;
  }

  Future<bool> deleteOwnPost(String postId) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty || !_isInitialized || _client == null) return false;

    try {
      final deletedRows = await _client!
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('profile_id', profileId)
          .select('id');
      final deleted = (deletedRows as List<dynamic>).isNotEmpty;
      if (deleted) notifyListeners();
      return deleted;
    } catch (e) {
      debugPrint('Error deleting own post in Supabase: $e');
      return false;
    }
  }

  Future<bool> isBookFavoritedByCurrentUser(String bookId) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty || !_isInitialized || _client == null) return false;
    try {
      final response = await _client!
          .from('favorites')
          .select('book_id')
          .eq('profile_id', profileId)
          .eq('book_id', bookId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('Error checking favorite in Supabase: $e');
      return false;
    }
  }

  Future<FavoriteToggleResult> toggleFavorite(String bookId) async {
    final profileId = activeProfileId;
    if (profileId.isEmpty) {
      debugPrint('Cannot toggle favorite: no authenticated user.');
      return FavoriteToggleResult.failed;
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
          notifyListeners();
          return FavoriteToggleResult.removed;
        } else {
          final existingFavorites = await _client!
              .from('favorites')
              .select('book_id')
              .eq('profile_id', profileId)
              .limit(12);
          if ((existingFavorites as List<dynamic>).length >= 12) {
            return FavoriteToggleResult.limitReached;
          }
          await _client!.from('favorites').insert({
            'profile_id': profileId,
            'book_id': bookId,
          });
          notifyListeners();
          return FavoriteToggleResult.added;
        }
      } catch (e) {
        debugPrint('Error toggling favorite in Supabase: $e');
        if (e.toString().contains('favorite_limit_reached')) {
          return FavoriteToggleResult.limitReached;
        }
      }
    }
    debugPrint('Supabase not initialized – favorite not toggled.');
    return FavoriteToggleResult.failed;
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
