import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:swift_speak/features/auth/login_screen.dart';
import 'package:swift_speak/features/home/home_screen.dart';
import 'package:swift_speak/features/home/home_screen.dart';
import 'package:swift_speak/features/overlay/overlay_toolbar.dart';

// overlay entry point
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("Starting Overlay Entry Point");
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayToolbar(),
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NOTE: This will fail without google-services.json
  // We wrap it in a try-catch to allow the app to launch for UI testing even if config is missing
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swift Speak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // If Firebase isn't initialized (e.g. missing config), show Login for testing UI
    if (Firebase.apps.isEmpty) {
      return const LoginScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
