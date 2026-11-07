import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/demo_store.dart';
import 'core/supabase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseProjectUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(VibePersApp(store: await DemoStore.load(), authEnabled: true));
}

class VibePersApp extends StatelessWidget {
  const VibePersApp({super.key, required this.store, this.authEnabled = false});
  final DemoStore store;
  final bool authEnabled;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vibe Pers',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF157A6E),
        primary: const Color(0xFF126E64),
        secondary: const Color(0xFFF6B943),
        surface: const Color(0xFFF8F7F2),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F7F2),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F7F2),
        foregroundColor: Color(0xFF173B38),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE7E9E4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    ),
    home: authEnabled ? AuthGate(store: store) : HomeScreen(store: store),
  );
}
