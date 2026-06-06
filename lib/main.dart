import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/book_list_screen.dart';
import 'screens/user_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SupabaseService. 
  // Reads credentials if provided via compile-time variables (e.g., flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...)
  // If not provided, it falls back gracefully to internal Mock data.
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
  
  final supabaseService = SupabaseService();
  await supabaseService.initialize(url: supabaseUrl, anonKey: supabaseKey);

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
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Off-white HSL(210, 20%, 98%)
        primaryColor: const Color(0xFFFF3B30), // Brand Red
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B30),
          brightness: Brightness.light,
          primary: const Color(0xFFFF3B30),
          secondary: const Color(0xFF264653), // Slate blue
          background: const Color(0xFFF8F9FA),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
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
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // Dark Navy HSL(224, 40%, 7%)
        primaryColor: const Color(0xFFFF3B30),
        cardColor: const Color(0xFF161F30), // Card Blue-Gray HSL(219, 37%, 14%)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B30),
          brightness: Brightness.dark,
          primary: const Color(0xFFFF3B30),
          secondary: const Color(0xFF4EA8DE),
          background: const Color(0xFF0B0F19),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentScreenIndex == 0
              ? BookListScreen(
                  key: const ValueKey('BookListScreen'),
                  onNavigateToProfile: () {
                    setState(() => _currentScreenIndex = 1);
                  },
                )
              : UserProfileScreen(
                  key: const ValueKey('UserProfileScreen'),
                  onBack: () {
                    setState(() => _currentScreenIndex = 0);
                  },
                ),
        ),
      ),
    );
  }
}
