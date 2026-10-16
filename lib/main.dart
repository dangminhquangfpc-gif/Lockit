import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/supabase_repository.dart';
import 'ui/auth_page.dart';
import 'ui/demo_session.dart';
import 'ui/social_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('DEMO_MODE');
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  var configured = false;
  if (!demo && url.startsWith('https://') && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, anonKey: key);
      configured = true;
    } catch (_) {
      // Never expose credentials or raw initialization errors in the UI.
    }
  }
  runApp(LockitApp(configured: configured, demo: demo));
}

class LockitApp extends StatelessWidget {
  const LockitApp({super.key, this.configured = false, this.demo = false});
  final bool configured;
  final bool demo;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lockit',
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAF8F2),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF285449),
            primary: const Color(0xFF285449),
            secondary: const Color(0xFFF4C95D),
            background: const Color(0xFFFAF8F2),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
        home: demo
            ? const DemoSession()
            : configured
                ? const AuthGate()
                : const SetupPage(),
      );
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.favorite_rounded, size: 72, color: Color(0xFF285449)),
              SizedBox(height: 24),
              Text('Lockit',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Một chút mỗi ngày, gần nhau hơn.',
                  textAlign: TextAlign.center),
              SizedBox(height: 24),
              Text('Ứng dụng đang được chuẩn bị. Vui lòng quay lại sau.',
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = client.auth.currentUser;
        if (user == null) return AuthPage(client: client);
        return SocialHome(
          key: ValueKey(user.id),
          repository: SupabaseRepository(client),
        );
      },
    );
  }
}
