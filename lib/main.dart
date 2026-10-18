import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'utils/responsive_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final showWelcome = await FirstLaunchStore.takeWelcomePage();
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
            if (authProvider == null) {
              provider.updateAuthentication(
                auth.isLoggedIn,
                FirebaseFirestore.instance,
              );
            }
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<EquipmentProvider, RequestProvider>(
          create: (context) =>
              RequestProvider(context.read<EquipmentProvider>()),
          update: (context, equipmentProvider, previous) =>
              previous!..updateEquipmentProvider(equipmentProvider),
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
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
