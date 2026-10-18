import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lendy/utils/session_preference_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not keep users signed in by default', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await SessionPreferenceStore.shouldKeepSignedIn(), isFalse);
  });

  test('stores the keep-signed-in choice', () async {
    SharedPreferences.setMockInitialValues({});

    await SessionPreferenceStore.setKeepSignedIn(true);
    expect(await SessionPreferenceStore.shouldKeepSignedIn(), isTrue);

    await SessionPreferenceStore.setKeepSignedIn(false);
    expect(await SessionPreferenceStore.shouldKeepSignedIn(), isFalse);
  });
}
