import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A deliberately lightweight translation system (a plain string map per
// language, rather than Flutter's full ARB/gen-l10n pipeline) so the
// language-switching feature can be demonstrated end-to-end without a
// build-time code generation step. Currently covers the Settings,
// Login, and Home-banner screens as a working proof of concept —
// extending coverage to every remaining screen would follow the exact
// same pattern (add keys here, replace hardcoded strings with
// AppStrings.of(context).t('key')) and is a reasonable next step
// beyond this project's current scope.
class LanguageState extends ChangeNotifier {
  String _languageCode = 'en';
  String get languageCode => _languageCode;

  LanguageState() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('languageCode') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', code);
    notifyListeners();
  }

  String t(String key) {
    return _strings[_languageCode]?[key] ?? _strings['en']?[key] ?? key;
  }

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'si': '\u0dc3\u0dd2\u0d82\u0dc4\u0dbd', // Sinhala, written natively
  };

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'welcome_back': 'Welcome back',
      'login_subtitle': 'Sign in to keep an eye on what matters',
      'log_in': 'Log In',
      'continue_with_google': 'Continue with Google',
      'no_account': 'Don\'t have an account? Sign up',
      'welcome_banner_named': 'Welcome, {name}!',
      'welcome_banner_default': 'Welcome to Sentri!',
      'welcome_banner_subtitle': 'Your smart companion is ready. Tap + to register your first belonging.',
      'settings_title': 'Settings',
      'settings_subtitle': 'Account, preferences, and more',
      'account': 'Account',
      'edit_name': 'Edit name',
      'change_password': 'Change password',
      'delete_account': 'Delete account',
      'preferences': 'Preferences',
      'notifications': 'Notifications',
      'temperature_unit': 'Temperature unit',
      'language': 'Language',
      'about': 'About',
      'log_out': 'Log out',
      'save': 'Save',
      'cancel': 'Cancel',
    },
    'si': {
      'welcome_back': '\u0d85\u0dc5\u0dd4\u0dad\u0dd2\u0db1\u0dca \u0db4\u0dd2\u0dbb\u0dd2\u0dc3\u0dd4\u0db1\u0dca',
      'login_subtitle': '\u0dc0\u0dd0\u0daf\u0da7\u0dca \u0dc0\u0db1\u0dca\u0d9a\u0db8\u0dca \u0dc3\u0dd2\u0dad\u0dd2\u0db1\u0dca \u0db4\u0dc3\u0dd4\u0d9c\u0dd0\u0db1\u0dd3\u0db8\u0da7 \u0db4\u0dca\u200d\u0dbb\u0dc0\u0dda\u0dc1 \u0dc0\u0db1\u0dca\u0db1',
      'log_in': '\u0db4\u0dca\u200d\u0dbb\u0dc0\u0dda\u0dc1 \u0dc0\u0db1\u0dca\u0db1',
      'continue_with_google': 'Google \u0dc3\u0db8\u0d9f \u0dbb\u0dd2\u0dba\u0da7',
      'no_account': '\u0d9c\u0dd2\u0dab\u0dd4\u0db8\u0d9a\u0dca \u0db1\u0dd0\u0dad\u0dca\u0dad\u0da7\u0da9? \u0db1\u0db3\u0dad\u0dc4\u0dd4\u0dbb\u0dd4 \u0dc0\u0db1\u0dca\u0db1',
      'welcome_banner_named': '\u0d86\u0dba\u0dd4\u0db6\u0ddd\u0dc0\u0db1\u0dca, {name}!',
      'welcome_banner_default': 'Sentri \u0dc0\u0dbb\u0da7 \u0d86\u0dba\u0dd4\u0db6\u0ddd\u0dc0\u0db1\u0dca!',
      'welcome_banner_subtitle': '\u0d94\u0da6\u0d9c\u0dda \u0dc3\u0dca\u0db8\u0dcf\u0dbb\u0dca\u0da7\u0dca \u0dc3\u0dc4\u0d9a\u0dbb\u0dd4 \u0dc3\u0dcf\u0daf\u0dcf\u0dba\u0dd2 \u0dad\u0dd2\u0dba\u0dda. \u0db4\u0dbd\u0dc0\u0dda\u0db1\u0dd2 \u0dc0\u0dc3\u0dad\u0dd4\u0dc0 \u0dbd\u0da2\u0dcf \u0d9a\u0dbb\u0db1\u0dca\u0db1 + \u0daf\u0db1\u0dca\u0db1.',
      'settings_title': '\u0dc3\u0dd0\u0da7\u0dd2\u0d82\u0dc3\u0dca',
      'settings_subtitle': '\u0d9c\u0dd2\u0dab\u0dd4\u0db8, \u0db4\u0dca\u200d\u0dbb\u0dcf\u0dad\u0dca\u200d\u0dba\u0dad\u0dcf \u0dc3\u0dc4 \u0dc0\u0dda\u0dbd\u0dd2\u0dad',
      'account': '\u0d9c\u0dd2\u0dab\u0dd4\u0db8',
      'edit_name': '\u0db1\u0db8 \u0dc3\u0d9a\u0dc3\u0dca \u0d9a\u0dbb\u0db1\u0dca\u0db1',
      'change_password': '\u0dc3\u0d9c\u0dc0\u0dc3\u0dca\u200d\u0d9a\u0dca\u0dc2\u0dba \u0dc0\u0dd0\u0db1\u0dc3\u0dca \u0d9a\u0dbb\u0db1\u0dca\u0db1',
      'delete_account': '\u0d9c\u0dd2\u0dab\u0dd4\u0db8 \u0d8a\u0dbb\u0db1\u0dca\u0db1',
      'preferences': '\u0db4\u0dca\u200d\u0dbb\u0dcf\u0dad\u0dca\u200d\u0dba\u0dad\u0dcf',
      'notifications': '\u0dd2\u0dc3\u0dc0\u0dd3\u0db8\u0dca',
      'temperature_unit': '\u0dad\u0dcf\u0db4 \u0dc0\u0dda\u0d9a',
      'language': '\u0db7\u0dcf\u0dc2\u0dcf\u0dc0',
      'about': '\u0db8\u0dd0\u0dad\u0dd2',
      'log_out': '\u0db1\u0dd2\u0d9c\u0dc0\u0db1\u0dca\u0db1',
      'save': '\u0dc3\u0dd4\u0dbb\u0d9a\u0dd2\u0db1\u0dca\u0db1',
      'cancel': '\u0dbb\u0dd0\u0dad\u0dd2 \u0d9a\u0dbb\u0db1\u0dca\u0db1',
    },
  };
}