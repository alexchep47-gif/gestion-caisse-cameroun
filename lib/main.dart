import 'package:flutter/material.dart';
import 'home.dart';
import 'pin_lock.dart';
import 'settings.dart';
import 'store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestionCaisseApp());
}

class GestionCaisseApp extends StatefulWidget {
  const GestionCaisseApp({super.key});

  @override
  State<GestionCaisseApp> createState() => _GestionCaisseAppState();
}

class _GestionCaisseAppState extends State<GestionCaisseApp> {
  final AppSettings settings = AppSettings();
  final CashStore store = CashStore();
  bool unlocked = false;

  @override
  void dispose() {
    settings.dispose();
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([settings, store]),
      builder: (context, _) {
        if (settings.isLoading || store.isLoading) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xff0f766e),
              body: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        final needLock = settings.hasPin && !unlocked;

        return MaterialApp(
          title: 'Ma Caisse',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: needLock
              ? PinLockScreen(
                  settings: settings,
                  onUnlocked: () => setState(() => unlocked = true),
                )
              : CashHomePage(
                  store: store,
                  settings: settings,
                  onLock: () => setState(() => unlocked = false),
                ),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const seed = Color(0xff0f766e);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor:
          isDark ? const Color(0xff0f1419) : const Color(0xffeef7f5),
      cardTheme: CardThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.64),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
