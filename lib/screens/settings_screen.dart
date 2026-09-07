import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/language_state.dart';
import '../widgets/app_widgets.dart';

// A single screen covering account management (view/edit profile,
// change password, delete account), app preferences (notifications,
// temperature unit, language), and sign-out — the usual home for
// these settings in most apps, consolidated here rather than
// scattered across other screens.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _name;
  String? _email;
  bool _isLoadingProfile = true;
  bool _notificationsEnabled = true;
  bool _useFahrenheit = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPreferences();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (mounted) {
      setState(() {
        _name = doc.data()?['name'] as String? ?? '';
        _email = user.email ?? '';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
        _useFahrenheit = prefs.getBool('useFahrenheit') ?? false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _toggleTemperatureUnit(bool useFahrenheit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useFahrenheit', useFahrenheit);
    setState(() => _useFahrenheit = useFahrenheit);
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.read<LanguageState>().t('edit_name')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.read<LanguageState>().t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(context.read<LanguageState>().t('save'))),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'name': newName});
      setState(() => _name = newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated.')));
      }
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Only email/password accounts have a password to change — Google
    // accounts manage their password through Google itself.
    final isPasswordUser = user.providerData.any((p) => p.providerId == 'password');
    if (!isPasswordUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account uses Google Sign-In, so there\'s no Sentri password to change.')),
      );
      return;
    }

    final currentController = TextEditingController();
    final newController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.read<LanguageState>().t('change_password'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Current password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'New password', helperText: 'At least 6 characters', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Update Password'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Firebase requires a recent login before allowing a password
      // change — re-authenticate with their current password first.
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentController.text);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final message = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Current password is incorrect.'
            : 'Could not update password: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete your account?'),
        content: const Text('This permanently deletes your Sentri account, all registered items, family profiles, routines, and health history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _reauthenticate(user);
      await _deleteAllUserData(user.uid);
      await user.delete();
      // No manual navigation needed — AuthState's auth-state listener
      // detects the account is gone and main.dart shows LoginScreen.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    }
  }

  // Firebase requires a recent sign-in before allowing account deletion.
  // Re-authenticates using whichever provider the account was created
  // with (email/password or Google).
  Future<void> _reauthenticate(User user) async {
    final isPasswordUser = user.providerData.any((p) => p.providerId == 'password');

    if (isPasswordUser) {
      final passwordController = TextEditingController();
      final password = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm your password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, passwordController.text), child: const Text('Confirm')),
          ],
        ),
      );

      if (password == null || password.isEmpty) {
        throw FirebaseAuthException(code: 'cancelled', message: 'Re-authentication cancelled.');
      }

      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
    } else {
      // Google-signed-in account — re-trigger the Google sign-in flow.
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final googleUser = await googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      await user.reauthenticateWithCredential(credential);
    }
  }

  // Firestore doesn't cascade-delete subcollections automatically, so
  // every subcollection has to be cleared out manually before the
  // parent user document (and the Auth account itself) is removed.
  Future<void> _deleteAllUserData(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    Future<void> deleteCollection(String path) async {
      final snapshot = await userRef.collection(path).get();
      for (final doc in snapshot.docs) {
        if (path == 'items') {
          final historySnapshot = await doc.reference.collection('locationHistory').get();
          for (final historyDoc in historySnapshot.docs) {
            await historyDoc.reference.delete();
          }
        }
        await doc.reference.delete();
      }
    }

    await deleteCollection('items');
    await deleteCollection('familyProfiles');
    await deleteCollection('routines');
    await deleteCollection('healthLogs');
    await userRef.delete();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageState>();

    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const BackgroundAccents(),
          Column(
            children: [
              GradientHeader(title: lang.t('settings_title'), subtitle: lang.t('settings_subtitle')),
              Expanded(
                child: _isLoadingProfile
                    ? const SkeletonListView(rowCount: 3)
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _sectionLabel(lang.t('account'), Icons.person_outline, kTeal),
                          const SizedBox(height: 8),
                          SentriCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const CircleAvatar(backgroundColor: Color(0xFFEAF6F2), child: Icon(Icons.person, color: kTeal)),
                                  title: Text(_name?.isNotEmpty == true ? _name! : 'No name set'),
                                  subtitle: Text(_email ?? ''),
                                  trailing: IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: _editName),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.lock_outline),
                                  title: Text(lang.t('change_password')),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _changePassword,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          _sectionLabel(lang.t('preferences'), Icons.tune, kBlue),
                          const SizedBox(height: 8),
                          SentriCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                SwitchListTile(
                                  secondary: const Icon(Icons.notifications_outlined),
                                  title: Text(lang.t('notifications')),
                                  value: _notificationsEnabled,
                                  activeThumbColor: kTeal,
                                  onChanged: _toggleNotifications,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.thermostat_outlined),
                                  title: Text(lang.t('temperature_unit')),
                                  trailing: SegmentedButton<bool>(
                                    segments: const [
                                      ButtonSegment(value: false, label: Text('\u00b0C')),
                                      ButtonSegment(value: true, label: Text('\u00b0F')),
                                    ],
                                    selected: {_useFahrenheit},
                                    onSelectionChanged: (s) => _toggleTemperatureUnit(s.first),
                                    style: SegmentedButton.styleFrom(selectedBackgroundColor: kTeal, selectedForegroundColor: Colors.white),
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.language_outlined),
                                  title: Text(lang.t('language')),
                                  trailing: DropdownButton<String>(
                                    value: lang.languageCode,
                                    underline: const SizedBox.shrink(),
                                    items: LanguageState.supportedLanguages.entries
                                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                        .toList(),
                                    onChanged: (code) {
                                      if (code != null) context.read<LanguageState>().setLanguage(code);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          _sectionLabel(lang.t('about'), Icons.info_outline, kPurple),
                          const SizedBox(height: 8),
                          const SentriCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sentri', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                SizedBox(height: 4),
                                Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                                SizedBox(height: 8),
                                Text('An AI-powered Smart Lifestyle Companion.', style: TextStyle(color: Colors.black87, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: BouncyTap(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  // Pop back to the root screen first, so
                                  // Settings (and anything else pushed on
                                  // top of it) isn't left stranded above
                                  // the LoginScreen that AuthState is
                                  // about to swap in underneath.
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                  await FirebaseAuth.instance.signOut();
                                },
                                icon: const Icon(Icons.logout, size: 18),
                                label: Text(lang.t('log_out')),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _deleteAccount,
                              icon: const Icon(Icons.delete_forever_outlined, size: 18, color: Colors.redAccent),
                              label: Text(lang.t('delete_account'), style: const TextStyle(color: Colors.redAccent)),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.3)),
      ],
    );
  }
}