import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../state/language_state.dart';
import 'signup_screen.dart';

// This is the first screen a user sees if they aren't logged in yet.
// It offers both email/password sign-in and a "Continue with Google"
// option, then hands off to Firebase Auth either way.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // main.dart listens for auth state changes and switches screens
      // automatically once Firebase confirms the login, so nothing
      // else needed here.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _friendlyErrorMessage(e.code);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': userCredential.user?.displayName ?? '',
          'email': userCredential.user?.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign-in failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sentri'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Gradient wash behind everything
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F6E56), Color(0xFFEAF6F2)],
                stops: [0.0, 0.55],
              ),
            ),
          ),

          // Soft decorative circle, top-right
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),

          // A second, smaller circle for depth, top-left
          Positioned(
            top: 90,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          // Actual content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Shield in a soft white badge instead of a plain icon,
                      // so it doesn't disappear against the gradient.
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, size: 56, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.watch<LanguageState>().t('welcome_back'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.watch<LanguageState>().t('login_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                      const SizedBox(height: 32),

                      // Card container so the form pops off the gradient
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'e.g. kasun@example.com',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 18),

                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: const Color(0xFF0F6E56),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(context.watch<LanguageState>().t('log_in')),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),

                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: Text(context.watch<LanguageState>().t('continue_with_google')),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupScreen()),
                          );
                        },
                        child: Text(
                          context.watch<LanguageState>().t('no_account'),
                          style: const TextStyle(color: Color(0xFF0F6E56), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}