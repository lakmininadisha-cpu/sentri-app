import 'package:flutter/material.dart';
import '../services/biometric_service.dart';

// Shown right after the user is confirmed logged in, before they can
// see any of their actual data. Requires fingerprint/Face ID (or device
// PIN as a fallback) to proceed — protects sensitive info like item
// photos and location history if the phone is picked up by someone else.
class LockScreen extends StatefulWidget {
  final Widget child; // the real app content shown once unlocked

  const LockScreen({super.key, required this.child});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isUnlocked = false;
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tryUnlock();
  }

  Future<void> _tryUnlock() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final biometricService = BiometricService();
    final isAvailable = await biometricService.isBiometricAvailable();

   if (!isAvailable) {
      // If the device/emulator has no biometric hardware set up at all,
      // we don't want to permanently lock the user out — just let them
      // through, since there's nothing to authenticate against.
      setState(() {
        _isUnlocked = true;
        _isAuthenticating = false;
      });
      return;
    }

    final success = await biometricService.authenticate();

    setState(() {
      _isUnlocked = success;
      _isAuthenticating = false;
      if (!success) {
        _errorMessage = 'Authentication failed or was cancelled.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 72, color: Color(0xFF0F6E56)),
              const SizedBox(height: 20),
              const Text(
                'Sentri is locked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verify your identity to continue',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),

              ElevatedButton.icon(
                onPressed: _isAuthenticating ? null : _tryUnlock,
                icon: _isAuthenticating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_open),
                label: Text(_isAuthenticating ? 'Verifying...' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}