import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const Lendy());
}

class Lendy extends StatelessWidget {
  const Lendy({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lendy',
      home: const LoginScreen(),
    );
  }
}
