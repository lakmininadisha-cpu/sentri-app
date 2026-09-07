import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'state/auth_state.dart';
import 'state/language_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/app_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().init();
  runApp(
    // AuthState and LanguageState are created once, at the very top of
    // the widget tree, so any screen further down can read the current
    // user or language without needing its own plumbing.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => LanguageState()),
      ],
      child: const SentriApp(),
    ),
  );
}

class SentriApp extends StatelessWidget {
  const SentriApp({super.key});

  @override
  Widget build(BuildContext context) {
    // A warm, rounded sans-serif (Manrope) for body text paired with a
    // slightly more expressive display font (Lexend) for headings —
    // chosen for readability and a friendlier feel than the platform
    // default, without needing any bundled font asset files.
    final baseTextTheme = GoogleFonts.manropeTextTheme();
    final textTheme = baseTextTheme.copyWith(
      headlineSmall: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 19),
      titleMedium: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 16),
    );

    return MaterialApp(
      title: 'Sentri',
      theme: ThemeData(
        colorSchemeSeed: kTeal,
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
        textTheme: textTheme,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
            TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
          },
        ),
      ),
      home: Consumer<AuthState>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(body: LoadingView());
          }
          if (auth.isLoggedIn) {
            if (auth.isNewSignup) {
              return OnboardingScreen(onFinished: () => auth.clearNewSignupFlag());
            }
            return const LockScreen(child: HomeScreen());
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// A gentle custom page transition — a soft fade combined with a small
// upward slide — used app-wide instead of Android's default abrupt
// push, so navigating between screens feels smoother and more considered.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}