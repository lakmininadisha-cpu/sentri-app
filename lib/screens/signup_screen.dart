import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../widgets/app_widgets.dart';

// New users land here to create an account. Once Firebase Auth creates
// the user, we also save a basic profile document in Firestore so we
// have somewhere to attach items, routines, etc. later on.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      // Flag this as a fresh signup so main.dart shows the onboarding
      // walkthrough on this first login, instead of going straight to
      // Home. AuthState's own auth-state listener still handles the
      // actual screen switch — we're not navigating manually here.
      if (mounted) context.read<AuthState>().markAsNewSignup();
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

  String _friendlyErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const BackgroundAccents(),
          Column(
            children: [
              const GradientHeader(
                title: 'Create Account',
                subtitle: 'Join Sentri in under a minute',
                height: 120,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      SentriCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Full name',
                                hintText: 'e.g. Nadeesha Perera',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'e.g. nadeesha@example.com',
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
                                helperText: 'At least 6 characters',
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
                              onPressed: _isLoading ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: kTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Sign Up'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Already have an account? Log in'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}