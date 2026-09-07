import 'package:local_auth/local_auth.dart';

// A small wrapper around local_auth for checking device biometric
// support and prompting the user to authenticate before they can
// see any of their items or personal data.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    return canCheckBiometrics && isDeviceSupported;
  }

  Future<bool> authenticate() async {
    try {
      // Newer versions of this package pass authentication flags
      // directly to authenticate() rather than wrapping them in a
      // separate AuthenticationOptions object.
      return await _auth.authenticate(
        localizedReason: 'Verify it\'s you to open Sentri',
        biometricOnly: false, // allow device PIN/pattern as a fallback too
      );
    } catch (e) {
      return false;
    }
  }
}