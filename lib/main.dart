import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'utils/responsive_layout.dart';

void main() {
  runApp(const SmartClassroomApp());
}

class SmartClassroomApp extends StatelessWidget {
  const SmartClassroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => EquipmentProvider()),
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
          '/splash': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/set-new-password': (_) => const SetNewPasswordScreen(),
          '/home': (_) => const MainShell(),
        },
      ),
    );
  }
}
