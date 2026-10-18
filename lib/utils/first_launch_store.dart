import 'package:shared_preferences/shared_preferences.dart';

class FirstLaunchStore {
  FirstLaunchStore._();

  static const _welcomeSeenKey = 'welcome_page_seen';

  static Future<bool> takeWelcomePage() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_welcomeSeenKey) ?? false) return false;
    if (!await preferences.setBool(_welcomeSeenKey, true)) {
      throw StateError('Could not save the first-launch welcome state.');
    }
    return true;
  }
}
