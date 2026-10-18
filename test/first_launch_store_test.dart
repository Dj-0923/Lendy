import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lendy/utils/first_launch_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shows welcome only once after a clean install', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await FirstLaunchStore.takeWelcomePage(), isTrue);
    expect(await FirstLaunchStore.takeWelcomePage(), isFalse);
  });

  test('does not show welcome when it was already seen', () async {
    SharedPreferences.setMockInitialValues({'welcome_page_seen': true});

    expect(await FirstLaunchStore.takeWelcomePage(), isFalse);
  });

  test('existing accounts never see first-launch welcome', () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await FirstLaunchStore.takeWelcomePage(hasExistingAccount: true),
      isFalse,
    );
    expect(await FirstLaunchStore.takeWelcomePage(), isFalse);
  });

  test('successful account use permanently marks welcome as seen', () async {
    SharedPreferences.setMockInitialValues({});

    await FirstLaunchStore.markWelcomeSeen();

    expect(await FirstLaunchStore.takeWelcomePage(), isFalse);
  });
}
