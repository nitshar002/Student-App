import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_app/services/ai_service.dart';
import 'package:student_app/services/database_service.dart';
import 'package:student_app/screens/dashboard_screen.dart';
import 'package:student_app/screens/syllabus_upload.dart';
import 'package:student_app/screens/wellness_screen.dart';
import 'package:student_app/screens/interview_screen.dart';
import 'package:student_app/screens/onboarding_screen.dart';
import 'package:student_app/services/wellness_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase using environment variables for security
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GeminiService>(create: (_) => GeminiService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<WellnessService>(create: (_) => WellnessService()),
      ],
      child: const StudentNexusApp(),
    ),
  );
}

class StudentNexusApp extends StatelessWidget {
  const StudentNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Nexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // Modern Indigo accent
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Cooler Slate-50 background
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0, // Prevents appbar from changing color when scrolling
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A), // Slate 900
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1), // Slate 200 border
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.5),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), letterSpacing: -0.2),
          bodyLarge: TextStyle(color: Color(0xFF334155)),
          bodyMedium: TextStyle(color: Color(0xFF475569)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFF1F5F9), thickness: 1, space: 1),
      ),
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
  int _currentIndex = 0;
  bool _hasCheckedAuth = false;
  bool _isAuthenticated = false;
  StreamSubscription<AuthState>? _authSubscription;

  final List<Widget> _screens = [
    const DashboardScreen(),
    SyllabusUploadScreen(),
    const WellnessScreen(),
    const InterviewScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      if (!mounted) return;

      setState(() {
        _hasCheckedAuth = true;
        _isAuthenticated = authState.session != null;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (!mounted) return;

    setState(() {
      _hasCheckedAuth = true;
      _isAuthenticated = user != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCheckedAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated) {
      return const OnboardingScreen();
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 16,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload),
            label: 'Syllabus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hotel_class),
            label: 'Wellness',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_alt),
            label: 'AI Prep',
          ),
        ],
      ),
    );
  }
}