import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/book_list_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/community_guidelines_screen.dart';
import 'screens/infringement_policy_screen.dart';
import 'screens/external_transmission_screen.dart';
import 'screens/legal_consent_screen.dart';
import 'screens/account_settings_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/profile_onboarding_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/moderation_screen.dart';
import 'screens/account_suspension_gate.dart';

enum _HeaderMenuAction { home, myPage, settings, help, moderation, logout }

final supabaseService = SupabaseService();

// 💡 パッケージを使わず、環境変数（JSON）から直接安全に引き抜く
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const supabaseRedirectUrl = String.fromEnvironment('SUPABASE_REDIRECT_URL');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase service
  await supabaseService.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    redirectUrl: supabaseRedirectUrl,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SupabaseService>.value(value: supabaseService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookCase',
      debugShowCheckedModeBanner: false,

      // Premium Light Theme Design System
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(
          0xFFF8F9FA,
        ), // Off-white HSL(210, 20%, 98%)
        primaryColor: const Color(0xFFFF3B30), // Brand Red
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B30),
          brightness: Brightness.light,
          primary: const Color(0xFFFF3B30),
          secondary: const Color(0xFF264653), // Slate blue
          surface: const Color(0xFFF8F9FA),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme)
            .copyWith(
              titleLarge: TextStyle(
                fontFamily: GoogleFonts.outfit().fontFamily,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF212529),
              ),
              bodyMedium: TextStyle(
                fontFamily: GoogleFonts.outfit().fontFamily,
                color: const Color(0xFF495057),
              ),
            ),
        dividerColor: const Color(0xFFE9ECEF),
      ),

      // Premium Dark Theme Design System
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(
          0xFF0B0F19,
        ), // Dark Navy HSL(224, 40%, 7%)
        primaryColor: const Color(0xFFFF3B30),
        cardColor: const Color(0xFF161F30), // Card Blue-Gray HSL(219, 37%, 14%)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B30),
          brightness: Brightness.dark,
          primary: const Color(0xFFFF3B30),
          secondary: const Color(0xFF4EA8DE),
          surface: const Color(0xFF0B0F19),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
            .copyWith(
              titleLarge: TextStyle(
                fontFamily: GoogleFonts.outfit().fontFamily,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              bodyMedium: TextStyle(
                fontFamily: GoogleFonts.outfit().fontFamily,
                color: const Color(0xFFCED4DA),
              ),
            ),
        dividerColor: const Color(0xFF2A3447),
      ),
      themeMode: ThemeMode.system, // Dynamically follow device preference
      routes: {
        '/login': (context) => const AuthScreen(),
        '/terms': (context) => const TermsScreen(),
        '/privacy': (context) => const PrivacyPolicyScreen(),
        '/community-guidelines': (context) => const CommunityGuidelinesScreen(),
        '/infringement-policy': (context) => const InfringementPolicyScreen(),
        '/external-transmission': (context) => const ExternalTransmissionScreen(),
        '/contact': (context) => const ContactScreen(),
      },
      onUnknownRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const AccountSuspensionGate(
          child: LegalConsentGate(
            child: ProfileOnboardingGate(child: MainNavigationShell()),
          ),
        ),
      ),

      home: const AccountSuspensionGate(
        child: LegalConsentGate(
          child: ProfileOnboardingGate(child: MainNavigationShell()),
        ),
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  static const Set<String> _transientQueryKeys = {
    'code',
    'state',
    'error',
    'error_code',
    'error_description',
    'provider_token',
    'refresh_token',
    'token_type',
    'expires_in',
    'privacy_password_recovery',
  };

  late int _currentScreenIndex;
  late bool _openPrivacyPasswordRecovery;
  String? _adminCheckedUserId;
  bool _isAdmin = false;

  Uri _normalizedFragmentUri(String fragment) {
    var value = fragment;
    if (value.startsWith('/#/')) {
      value = value.substring(2);
    }
    if (value == '/#' || value == '/#/') {
      value = '/';
    }
    if (value.isEmpty) {
      value = '/';
    }
    if (!value.startsWith('/')) {
      value = '/$value';
    }
    return Uri.parse(value);
  }

  String _currentAppPathFromUri(Uri uri) {
    final fragment = uri.fragment;
    if (fragment.startsWith('/')) {
      return _normalizedFragmentUri(fragment).path;
    }
    return uri.path;
  }

  bool _hasTransientQuery(Uri uri) {
    for (final key in uri.queryParameters.keys) {
      if (_transientQueryKeys.contains(key)) return true;
    }
    if (uri.fragment.startsWith('/')) {
      for (final key in _normalizedFragmentUri(uri.fragment).queryParameters.keys) {
        if (_transientQueryKeys.contains(key)) return true;
      }
    }
    return false;
  }

  Map<String, String> _sanitizedQuery(Uri uri) {
    final sanitized = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      if (_transientQueryKeys.contains(key)) return;
      sanitized[key] = value;
    });
    return sanitized;
  }

  Map<String, String> _sanitizedFragmentQuery(Uri uri) {
    final sanitized = <String, String>{};
    if (!uri.fragment.startsWith('/')) return sanitized;
    _normalizedFragmentUri(uri.fragment).queryParameters.forEach((key, value) {
      if (_transientQueryKeys.contains(key)) return;
      sanitized[key] = value;
    });
    return sanitized;
  }

  int _screenIndexFromPath(String path) {
    switch (path) {
      case '/mypage':
      case '/profile':
      case '/user':
        return 1;
      case '/settings':
        return 2;
      case '/help':
        return 3;
      case '/moderation':
        return 4;
      default:
        return _openPrivacyPasswordRecovery ? 2 : 0;
    }
  }

  String _pathForScreenIndex(int index) {
    switch (index) {
      case 1:
        return '/mypage';
      case 2:
        return '/settings';
      case 3:
        return '/help';
      case 4:
        return '/moderation';
      default:
        return '/';
    }
  }

  void _syncBrowserUrlForScreen(int index, {bool replace = false}) {
    final targetPath = _pathForScreenIndex(index);
    final currentUri = Uri.base;
    final currentAppPath = _currentAppPathFromUri(currentUri);
    final hasTransientQuery = _hasTransientQuery(currentUri);
    if (currentAppPath == targetPath && !hasTransientQuery) return;

    final sanitizedQuery = _sanitizedQuery(currentUri);
    final sanitizedFragmentQuery = _sanitizedFragmentQuery(currentUri);

    final targetUri = currentUri.fragment.startsWith('/')
        ? Uri(
            path: currentUri.path.isEmpty ? '/' : currentUri.path,
            queryParameters: sanitizedQuery.isEmpty ? null : sanitizedQuery,
            fragment: Uri(
              path: targetPath,
              queryParameters: sanitizedFragmentQuery.isEmpty
                  ? null
                  : sanitizedFragmentQuery,
            ).toString(),
          )
        : Uri(
            path: targetPath,
            queryParameters: sanitizedQuery.isEmpty ? null : sanitizedQuery,
          );

    SystemNavigator.routeInformationUpdated(
      uri: targetUri,
      replace: replace,
    );
  }

  void _setCurrentScreenIndex(int index, {bool replaceUrl = false}) {
    if (_currentScreenIndex != index) {
      setState(() {
        _currentScreenIndex = index;
      });
    }
    _syncBrowserUrlForScreen(index, replace: replaceUrl);
  }

  @override
  void initState() {
    super.initState();
    final currentUri = Uri.base;
    final fragmentQuery = currentUri.fragment.startsWith('/')
        ? _normalizedFragmentUri(currentUri.fragment).queryParameters
        : const <String, String>{};
    _openPrivacyPasswordRecovery =
        (currentUri.queryParameters['privacy_password_recovery'] == '1') ||
        (fragmentQuery['privacy_password_recovery'] == '1');
    _currentScreenIndex = _screenIndexFromPath(_currentAppPathFromUri(currentUri));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncBrowserUrlForScreen(_currentScreenIndex, replace: true);
    });
  }

  Future<void> _checkAdministratorAccess(
    SupabaseService service,
    String userId,
  ) async {
    final isAdmin = await service.isCurrentUserAdmin();
    if (!mounted || service.activeProfileId != userId) return;
    setState(() => _isAdmin = isAdmin);
  }

  Future<void> _goToProfile() async {
    final service = Provider.of<SupabaseService>(context, listen: false);
    if (!service.isAuthenticated) {
      final result = await Navigator.of(context).pushNamed('/login');
      if (result != true && !service.isAuthenticated) {
        return;
      }
    }

    await service.ensureCurrentUserProfile();
    if (!mounted) return;
    _setCurrentScreenIndex(1);
  }

  void _goToBookList() {
    _setCurrentScreenIndex(0);
  }

  Future<void> _onMenuAction(_HeaderMenuAction action) async {
    switch (action) {
      case _HeaderMenuAction.home:
        _goToBookList();
        break;
      case _HeaderMenuAction.myPage:
        await _goToProfile();
        break;
      case _HeaderMenuAction.settings:
        _setCurrentScreenIndex(2);
        break;
      case _HeaderMenuAction.help:
        _setCurrentScreenIndex(3);
        break;
      case _HeaderMenuAction.moderation:
        if (_isAdmin) _setCurrentScreenIndex(4);
        break;
      case _HeaderMenuAction.logout:
        final service = Provider.of<SupabaseService>(context, listen: false);
        await service.signOut();
        if (!mounted) return;
        _goToBookList();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ログアウトしました。')));
        break;
    }
  }

  String _currentHeaderTitle() {
    switch (_currentScreenIndex) {
      case 1:
        return 'マイページ';
      case 2:
        return '設定';
      case 3:
        return 'ヘルプ';
      case 4:
        return '管理';
      default:
        return 'ホーム';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseService>(
      builder: (context, service, _) {
        final currentUserId = service.activeProfileId;
        if (_adminCheckedUserId != currentUserId) {
          _adminCheckedUserId = currentUserId;
          _isAdmin = false;
          if (currentUserId.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _checkAdministratorAccess(service, currentUserId),
            );
          }
        }
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final menuIconColor = isDarkMode ? Colors.white : Colors.black;
        final popupMenuTextColor = isDarkMode ? Colors.black : Colors.black;
        final headerSideWidth = service.isAuthenticated ? 146.0 : 104.0;

        // If auth is lost while on profile, force navigation back to list.
        if (!service.isAuthenticated &&
            (_currentScreenIndex == 1 || _currentScreenIndex == 4)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _goToBookList();
            }
          });
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 60,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFF1D600),
                      width: 3,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: headerSideWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PopupMenuButton<_HeaderMenuAction>(
                            tooltip: 'メニュー',
                            icon: Icon(
                              Icons.menu,
                              size: 38,
                              color: menuIconColor,
                            ),
                            position: PopupMenuPosition.under,
                            color: Colors.white,
                            onSelected: _onMenuAction,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: _HeaderMenuAction.home,
                                child: Text(
                                  'ホーム',
                                  style: TextStyle(
                                    fontSize: 28 / 2,
                                    color: popupMenuTextColor,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: _HeaderMenuAction.myPage,
                                child: Text(
                                  'マイページ',
                                  style: TextStyle(
                                    fontSize: 28 / 2,
                                    color: popupMenuTextColor,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: _HeaderMenuAction.settings,
                                child: Text(
                                  '設定',
                                  style: TextStyle(
                                    fontSize: 28 / 2,
                                    color: popupMenuTextColor,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: _HeaderMenuAction.help,
                                child: Text(
                                  'ヘルプ',
                                  style: TextStyle(
                                    fontSize: 28 / 2,
                                    color: popupMenuTextColor,
                                  ),
                                ),
                              ),
                              if (_isAdmin)
                                PopupMenuItem(
                                  value: _HeaderMenuAction.moderation,
                                  child: Text(
                                    '管理',
                                    style: TextStyle(
                                      fontSize: 28 / 2,
                                      color: popupMenuTextColor,
                                    ),
                                  ),
                                ),
                              PopupMenuItem(
                                value: _HeaderMenuAction.logout,
                                child: Text(
                                  'ログアウト',
                                  style: TextStyle(
                                    fontSize: 28 / 2,
                                    color: popupMenuTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _currentHeaderTitle(),
                              style: const TextStyle(
                                color: Color(0xFFF1D600),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: headerSideWidth,
                        height: 36,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (service.isAuthenticated)
                              const SizedBox(
                                width: 42,
                                child: NotificationBellButton(),
                              ),
                            SizedBox(
                              width: 104,
                              height: 36,
                              child: ElevatedButton.icon(
                                onPressed: _goToProfile,
                                icon: Icon(
                                  service.isAuthenticated
                                      ? Icons.person_outline
                                      : Icons.login,
                                  size: 16,
                                ),
                                label: Text(
                                  service.isAuthenticated
                                      ? 'プロフィール'
                                      : 'ログイン',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF3B30),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentScreenIndex == 0
                        ? const BookListScreen(key: ValueKey('BookListScreen'))
                        : _currentScreenIndex == 1
                        ? UserProfileScreen(
                            key: const ValueKey('UserProfileScreen'),
                            onBack: _goToBookList,
                            showAppBar: false,
                          )
                        : _currentScreenIndex == 2
                        ? AccountSettingsScreen(
                            key: const ValueKey('SettingsScreen'),
                            onAccountDeleted: _goToBookList,
                            openPrivacyPasswordRecovery:
                                _openPrivacyPasswordRecovery,
                          )
                        : _currentScreenIndex == 3
                        ? const _HelpScreen(key: ValueKey('HelpScreen'))
                        : const ModerationScreen(
                            key: ValueKey('ModerationScreen'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HelpScreen extends StatelessWidget {
  const _HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_HelpItem>[
      _HelpItem(title: '利用規約', screenBuilder: (_) => const TermsScreen()),
      _HelpItem(
        title: 'プライバシーポリシー',
        screenBuilder: (_) => const PrivacyPolicyScreen(),
      ),
      _HelpItem(
        title: 'コミュニティガイドライン',
        screenBuilder: (_) => const CommunityGuidelinesScreen(),
      ),
      _HelpItem(
        title: '権利侵害・通報ポリシー',
        screenBuilder: (_) => const InfringementPolicyScreen(),
      ),
      _HelpItem(
        title: '外部送信に関する公表事項',
        screenBuilder: (_) => const ExternalTransmissionScreen(),
      ),
      _HelpItem(title: 'お問い合わせ', screenBuilder: (_) => const ContactScreen()),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '規約・ポリシー',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              );
            }

            final item = items[index - 1];
            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(item.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: item.screenBuilder));
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HelpItem {
  const _HelpItem({required this.title, required this.screenBuilder});

  final String title;
  final WidgetBuilder screenBuilder;
}
