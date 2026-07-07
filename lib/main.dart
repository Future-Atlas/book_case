import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/book_list_screen.dart'; // 👈 これを追加
import 'screens/user_profile_screen.dart';
import 'screens/auth_screen.dart';

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
  int _currentScreenIndex = 0; // 0 = BookList, 1 = UserProfile

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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentScreenIndex == 0
                  ? BookListScreen(
                      key: const ValueKey('BookListScreen'),
                      onNavigateToProfile: _goToProfile,
                    )
                  : UserProfileScreen(
                      key: const ValueKey('UserProfileScreen'),
                      onBack: _goToBookList,
                    ),
            ),
          ),
        );
      },
    );
  }
}
