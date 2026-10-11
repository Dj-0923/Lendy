// lib/screens/login_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'request_account_screen.dart';

const Color _teal = Color(0xFF1F7F74);
const Color _labelColor = Color(0xFF1A1A1A);
const Color _hintColor = Color(0xFF9AA0A6);
const Color _borderColor = Color(0xFFD5D9DD);
const Color _mutedText = Color(0xFF6B7280);

const double _formTopPadding = 54;
const double _fieldHeight = 42;
const double _fieldRadius = 8;
const double _labelToField = 7;
const double _rowGap = 60;
const double _fieldGap =
    6; // space between the Email block and the Password block
const double _buttonHeight = 42;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _keepSignedIn = false;
  bool _isLoading = false;

  // "Tap again to exit" (double-back-to-exit)
  DateTime? _lastBackPress;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleBackPress() {
    final now = DateTime.now();
    final pressedTwice =
        _lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2);

    if (pressedTwice) {
      SystemNavigator.pop(); // closes the app
      return;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Tap again to exit',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    final ok = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v);
    return ok ? null : 'Enter a valid email address';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Admin-issued temporary passwords must be changed before continuing.
    if (auth.currentUser!.mustChangePassword) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/set-new-password', (_) => false);
    } else {
      // Student and Faculty share the exact same dashboard shell.
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // never go back to the welcome page
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final frameWidth = constraints.maxWidth
                .clamp(0.0, 620.0)
                .toDouble();
            final headerHeight = constraints.maxHeight * .4;
            final scale = math
                .min(
                  (frameWidth / 393).clamp(.58, 1.0).toDouble(),
                  (headerHeight / 341).clamp(.55, 1.0).toDouble(),
                )
                .toDouble();
            final sidePadding = (frameWidth * .125)
                .clamp(24.0, 49.0)
                .toDouble();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SizedBox(
                  width: double.infinity,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Container(
                              width: double.infinity,
                              color: const Color(0xFF0F4844),
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned(
                                    top: headerHeight * .8,
                                    right: 25 * scale,
                                    child: _decorCircle(140 * scale),
                                  ),
                                  Positioned(
                                    top: headerHeight * .53,
                                    right: 43 * scale,
                                    child: _decorCircle(180 * scale),
                                  ),
                                  Positioned(
                                    top: headerHeight * .79,
                                    left: -70 * scale,
                                    child: _decorCircle(200 * scale),
                                  ),
                                  Positioned(
                                    top: -15 * scale,
                                    right: -15 * scale,
                                    child: Transform.scale(
                                      scale: scale,
                                      alignment: Alignment.topRight,
                                      child: _buildDotGrid(),
                                    ),
                                  ),
                                  Positioned(
                                    top: headerHeight * .44,
                                    left: 34 * scale,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Welcome to',
                                          style: GoogleFonts.inter(
                                            fontSize: 20 * scale,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            height: 1,
                                          ),
                                        ),
                                        Text(
                                          'Lendy',
                                          style: GoogleFonts.inter(
                                            fontSize: 60 * scale,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            height: .9,
                                          ),
                                        ),
                                        Text(
                                          'Campus Access',
                                          style: GoogleFonts.inter(
                                            fontSize: 28 * scale,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.white,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: _buildFormSection(
                              sidePadding: sidePadding,
                              scale: scale,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: headerHeight - 100 * scale,
                        right: 35 * scale,
                        child: _buildLogoBadge(scale),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════
  // LOGIN FORM
  // ════════════════════════════════
  Widget _buildFormSection({
    required double sidePadding,
    required double scale,
  }) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    sidePadding,
                    _formTopPadding * scale,
                    sidePadding,
                    16 + keyboard,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Email ──
                        _buildLabel('Email Address'),
                        const SizedBox(height: _labelToField),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'username@gmail.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                        ),

                        const SizedBox(height: _fieldGap),

                        // ── Password ──
                        _buildLabel('Password'),
                        const SizedBox(height: _labelToField),
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'enter your password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          suffix: IconButton(
                            splashRadius: 18,
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: _hintColor,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          validator: _validatePassword,
                        ),

                        // ── Forgot password? ──
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style:
                                TextButton.styleFrom(
                                  foregroundColor: _teal,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  splashFactory: InkRipple.splashFactory,
                                ).copyWith(
                                  overlayColor: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.pressed)
                                        ? _teal.withValues(alpha: 0.18)
                                        : null,
                                  ),
                                ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Forgot password?',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _teal,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: (_rowGap - 8) * scale),

                        // ── Keep me signed in ──
                        _buildKeepSignedIn(),

                        const SizedBox(height: 10),

                        // ── Sign in ──
                        SizedBox(
                          width: double.infinity,
                          height: _buttonHeight,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _teal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  _fieldRadius,
                                ),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Sign in',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Don't have an account? Request account (pinned at bottom) ──
              Padding(
                padding: const EdgeInsets.only(bottom: 80, top: 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: GoogleFonts.inter(fontSize: 12, color: _mutedText),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      splashColor: _teal.withValues(alpha: 0.18),
                      highlightColor: _teal.withValues(alpha: 0.10),
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RequestAccountScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          'Request Account',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _teal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _labelColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    String? Function(String?)? validator,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      cursorColor: _teal,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _labelColor,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: _hintColor),
        // Reserve one line under the field so nothing shifts when an error appears.
        helperText: ' ',
        helperStyle: GoogleFonts.inter(fontSize: 11, height: 1.2),
        errorStyle: GoogleFonts.inter(
          fontSize: 11,
          height: 1.2,
          color: Colors.red.shade700,
        ),
        errorMaxLines: 1,
        helperMaxLines: 1,
        prefixIcon: Icon(prefixIcon, size: 18, color: _teal),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 40),
        constraints: const BoxConstraints(minHeight: _fieldHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: (_fieldHeight - 18) / 2,
        ),
        enabledBorder: border(_borderColor),
        focusedBorder: border(_teal, 1.5),
        errorBorder: border(Colors.red.shade700),
        focusedErrorBorder: border(Colors.red.shade700, 1.5),
      ),
    );
  }

  Widget _buildKeepSignedIn() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _keepSignedIn = !_keepSignedIn),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: _keepSignedIn,
              onChanged: (v) => setState(() => _keepSignedIn = v ?? false),
              activeColor: _teal,
              side: const BorderSide(color: _hintColor, width: 1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Keep me signed in',
            style: GoogleFonts.inter(fontSize: 12, color: _mutedText),
          ),
        ],
      ),
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildLogoBadge(double scale) {
    return Container(
      width: 144 * scale,
      height: 144 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 120 * scale,
          height: 120 * scale,
          child: Image.asset('assets/images/Lendy.png'),
        ),
      ),
    );
  }

  Widget _buildDotGrid() {
    return Transform.rotate(
      angle: 0.785398, // 45 degrees in radians
      child: Column(
        children: List.generate(4, (row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (col) {
              return Padding(
                padding: const EdgeInsets.all(3.5),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
