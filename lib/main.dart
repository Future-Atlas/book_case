import 'package:flutter/material.dart';
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
      routes: {'/login': (context) => const AuthScreen()},

      home: const LegalConsentGate(child: MainNavigationShell()),
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
        return 'ホーム';
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
                      SizedBox(
                        width: 104,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PopupMenuButton<_HeaderMenuAction>(
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
                        ),
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
                            service.isAuthenticated ? 'プロフィール' : 'ログイン',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
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
                          )
                        : const _HelpScreen(key: ValueKey('HelpScreen')),
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
