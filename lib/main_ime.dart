import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/ime/keyboard_page.dart';
import 'package:google_fonts/google_fonts.dart';

@pragma('vm:entry-point')
void imeMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed in IME: $e");
  }
  runApp(const ImeApp());
}

class ImeApp extends StatelessWidget {
  const ImeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.ebGaramondTextTheme(ThemeData.dark().textTheme),
      ),
      home: const KeyboardPage(),
    );
  }
}
