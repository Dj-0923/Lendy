import 'package:shared_preferences/shared_preferences.dart';

class SessionPreferenceStore {
  SessionPreferenceStore._();

  static const _keepSignedInKey = 'keep_user_signed_in';

  static Future<bool> shouldKeepSignedIn() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keepSignedInKey) ?? false;
  }

  static Future<void> setKeepSignedIn(bool keepSignedIn) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_keepSignedInKey, keepSignedIn)) {
      throw StateError('Could not save the sign-in preference.');
    }
  }
}
