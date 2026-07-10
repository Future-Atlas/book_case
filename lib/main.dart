import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/book_list_screen.dart'; // 👈 これを追加
import 'screens/user_profile_screen.dart';
import 'screens/auth_screen.dart';

enum _HeaderMenuAction { myPage, settings, help, logout }

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
          background: const Color(0xFFF8F9FA),
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
          background: const Color(0xFF0B0F19),
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
      routes: {'/login': (context) => const AuthScreen()},

      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentScreenIndex =
      0; // 0 = BookList, 1 = UserProfile, 2 = Settings, 3 = Help

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
    setState(() {
      _currentScreenIndex = 1;
    });
  }

  void _goToBookList() {
    setState(() {
      _currentScreenIndex = 0;
    });
  }

  Future<void> _onMenuAction(_HeaderMenuAction action) async {
    switch (action) {
      case _HeaderMenuAction.myPage:
        await _goToProfile();
        break;
      case _HeaderMenuAction.settings:
        setState(() => _currentScreenIndex = 2);
        break;
      case _HeaderMenuAction.help:
        setState(() => _currentScreenIndex = 3);
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
      default:
        return 'ヘッダー';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseService>(
      builder: (context, service, _) {
        // If auth is lost while on profile, force navigation back to list.
        if (!service.isAuthenticated && _currentScreenIndex == 1) {
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
                      PopupMenuButton<_HeaderMenuAction>(
                        tooltip: 'メニュー',
                        icon: const Icon(
                          Icons.menu,
                          size: 38,
                          color: Colors.black,
                        ),
                        position: PopupMenuPosition.under,
                        color: Colors.white,
                        onSelected: _onMenuAction,
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _HeaderMenuAction.myPage,
                            child: Text(
                              'マイページ',
                              style: TextStyle(fontSize: 28 / 2),
                            ),
                          ),
                          PopupMenuItem(
                            value: _HeaderMenuAction.settings,
                            child: Text(
                              '設定',
                              style: TextStyle(fontSize: 28 / 2),
                            ),
                          ),
                          PopupMenuItem(
                            value: _HeaderMenuAction.help,
                            child: Text(
                              'ヘルプ',
                              style: TextStyle(fontSize: 28 / 2),
                            ),
                          ),
                          PopupMenuItem(
                            value: _HeaderMenuAction.logout,
                            child: Text(
                              'ログアウト',
                              style: TextStyle(fontSize: 28 / 2),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
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
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentScreenIndex == 0
                        ? BookListScreen(
                            key: const ValueKey('BookListScreen'),
                            onNavigateToProfile: _goToProfile,
                          )
                        : _currentScreenIndex == 1
                        ? UserProfileScreen(
                            key: const ValueKey('UserProfileScreen'),
                            onBack: _goToBookList,
                            showAppBar: false,
                          )
                        : _currentScreenIndex == 2
                        ? const _SimplePlaceholderScreen(
                            key: ValueKey('SettingsScreen'),
                            title: '設定',
                            message: '設定画面はこれから実装します。',
                          )
                        : const _SimplePlaceholderScreen(
                            key: ValueKey('HelpScreen'),
                            title: 'ヘルプ',
                            message: 'ヘルプ画面はこれから実装します。',
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

class _SimplePlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;

  const _SimplePlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(message, style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
