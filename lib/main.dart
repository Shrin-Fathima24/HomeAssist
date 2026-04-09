import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_fixed.dart' as login;
import 'signup_page.dart';
import 'splash_screen.dart';

import 'screens/worker_profile.dart';
import 'screens/earnings_page.dart';
import 'screens/user_profile.dart';
import 'screens/worker_signup_completion.dart';
import 'screens/admin_workers.dart';
import 'screens/user_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureHome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE6E6FA), // Light lavender seed
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8FF), // Light lavender bg
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF9370DB), // Lavender appbar
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9370DB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const login.LoginPage(),
        '/signup': (context) => SignupPage(),
        '/worker_signup_completion': (context) => WorkerSignupCompletionPage(),
        '/admin_workers': (context) => AdminWorkersScreen(),
        '/user_home': (context) => const UserDashboardScreen(),
        '/user_profile': (context) => UserProfileScreen(),
        '/worker_home': (context) => WorkerProfileScreen(),
        '/earnings': (context) => EarningsPage(),
      },
    );
  }
}
