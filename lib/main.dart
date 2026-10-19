import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/equipment_provider.dart';
import 'providers/request_provider.dart';
import 'providers/notification_provider.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/set_new_password_screen.dart';
import 'screens/main_shell.dart';
import 'utils/first_launch_store.dart';
import 'utils/session_preference_store.dart';
import 'utils/responsive_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  const notificationChannel = AndroidNotificationChannel(
    'lendy_alerts',
    'Lendy alerts',
    description: 'Borrowing requests and return reminders',
    importance: Importance.high,
  );
  final localNotifications = FlutterLocalNotificationsPlugin();
  if (!kIsWeb) {
    await localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(notificationChannel);
  }
  final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
  final showWelcome = await FirstLaunchStore.takeWelcomePage(
    hasExistingAccount: firebaseUser != null,
  );
  if (firebaseUser != null &&
      !await SessionPreferenceStore.shouldKeepSignedIn()) {
    await firebase_auth.FirebaseAuth.instance.signOut();
  }
  runApp(SmartClassroomApp(showWelcome: showWelcome));
}

class SmartClassroomApp extends StatelessWidget {
  const SmartClassroomApp({
    super.key,
    this.authProvider,
    this.showWelcome = true,
  });

  final AuthProvider? authProvider;
  final bool showWelcome;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider ?? AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, EquipmentProvider>(
          create: (_) => EquipmentProvider(
            firestore: authProvider == null ? FirebaseFirestore.instance : null,
          ),
          update: (_, auth, equipment) {
            final provider = equipment!;
            final user = auth.currentUser;
            final accountReady = user != null && !user.mustChangePassword;
            if (authProvider == null) {
              provider.updateAuthentication(
                accountReady,
                FirebaseFirestore.instance,
              );
            }
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          EquipmentProvider,
          RequestProvider
        >(
          create: (context) => RequestProvider(
            context.read<EquipmentProvider>(),
            firestore: authProvider == null ? FirebaseFirestore.instance : null,
          ),
          update: (context, auth, equipmentProvider, previous) {
            final user = auth.currentUser;
            final accountReady = user != null && !user.mustChangePassword;
            final provider =
                previous ??
                RequestProvider(
                  equipmentProvider,
                  firestore: authProvider == null
                      ? FirebaseFirestore.instance
                      : null,
                );
            provider
              ..updateEquipmentProvider(equipmentProvider)
              ..updateAuthentication(userId: accountReady ? user.id : null);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(
            firestore: authProvider == null ? FirebaseFirestore.instance : null,
            messaging: authProvider == null && !kIsWeb
                ? FirebaseMessaging.instance
                : null,
            localNotifications: authProvider == null && !kIsWeb
                ? FlutterLocalNotificationsPlugin()
                : null,
          ),
          update: (_, auth, notifications) {
            final user = auth.currentUser;
            final accountReady = user != null && !user.mustChangePassword;
            notifications!.updateAuthentication(
              userId: accountReady ? user.id : null,
            );
            return notifications;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Lendy',
        debugShowCheckedModeBanner: false,
        // See lib/utils/responsive_layout.dart for app-wide responsive sizing
        // and its breakpoints.
        builder: (context, child) =>
            ResponsiveAppFrame(child: child ?? const SizedBox.shrink()),
        theme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (_) => SplashScreen(showWelcome: showWelcome),
          '/login': (_) => const LoginScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/set-new-password': (_) => const SetNewPasswordScreen(),
          '/home': (_) => const MainShell(),
        },
      ),
    );
  }
}
