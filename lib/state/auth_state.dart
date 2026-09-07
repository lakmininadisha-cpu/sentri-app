import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Centralises Firebase's authentication state behind the Provider
// package (an implementation of the Observer design pattern), rather
// than wiring a raw StreamBuilder<User?> directly into main.dart. Any
// widget in the tree can now ask "who is logged in?" via
// context.watch<AuthState>() without needing its own stream plumbing.
class AuthState extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  bool _isNewSignup = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isNewSignup => _isNewSignup;

  AuthState() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  // Called by the signup screen right after successfully creating an
  // account, so main.dart knows to route through the onboarding
  // walkthrough instead of straight to Home on this first login.
  void markAsNewSignup() {
    _isNewSignup = true;
    notifyListeners();
  }

  // Called once the onboarding walkthrough finishes (or is skipped),
  // so subsequent app opens go straight to Home as normal.
  void clearNewSignupFlag() {
    _isNewSignup = false;
    notifyListeners();
  }
}