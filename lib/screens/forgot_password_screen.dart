// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Forgot Password screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // Colours come straight from the design, so they stay local to this screen.
  static const Color _teal = Color(0xFF16847D);
  static const Color _body = Color(0xFF687572);
  static const Color _label = Color(0xFF1E302D);
  static const Color _fieldLine = Color(0xFFD7DEDC);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  Future<void> _handleSendReset() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().sendPasswordReset(
      _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error, Colors.redAccent);
      return;
    }

    _showMessage('Reset link sent! Please check your email.', _teal);
    Navigator.pop(context); // back to Login
  }

  void _showMessage(String text, Color background) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: background));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth < 360 ? 24.0 : 32.0;
            final headerHeight = (constraints.maxWidth * .65).clamp(
              220.0,
              285.0,
            );

            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _Header(height: headerHeight),
                    Padding(
                      padding: EdgeInsets.fromLTRB(padding, 32, padding, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Forgot password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _teal,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No worries! Enter the email address associated with\n'
                            'your account and we’ll send you a link to reset\n'
                            'your password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _body,
                              fontSize: 13,
                              height: 1.42,
                            ),
                          ),
                          const SizedBox(height: 31),
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              color: _label,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSendReset(),
                            validator: _validateEmail,
                            decoration: InputDecoration(
                              hintText: 'e.g. username@gmail.com',
                              hintStyle: const TextStyle(color: _body),
                              prefixIcon: const Icon(
                                Icons.mail_outline_rounded,
                                color: _teal,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 17,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide: const BorderSide(color: _fieldLine),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide: const BorderSide(
                                  color: _teal,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide: const BorderSide(
                                  color: Colors.redAccent,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide: const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _handleSendReset,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined),
                              label: Text(
                                _isLoading ? 'Sending...' : 'Send Reset Email',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 29),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 17),
                                child: Text('OR'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 25),
                          // The icon and its text size to their own content and
                          // are centred as one group, instead of the text being
                          // stretched to the full column width.
                          const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoLockIcon(),
                                SizedBox(width: 12),
                                Flexible(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Make sure to use the email associated\n'
                                      'with your account.',
                                      style: TextStyle(
                                        color: _body,
                                        fontSize: 12.5,
                                        height: 1.4,
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            height: height,
            color: const Color(0xFF0C4D49),
            child: const Stack(
              children: [
                Positioned(
                  left: -82,
                  top: 148,
                  child: _BackgroundCircle(
                    size: 180,
                    color: Color(0xFF2A716B),
                    outline: 1.5,
                  ),
                ),
                // right circle
                Positioned(
                  right: -82,
                  top: 168,
                  child: _BackgroundCircle(
                    size: 240,
                    color: Color(0xFF2A716B),
                    outline: 1.5,
                  ),
                ),
                // ring - top right
                Positioned(
                  right: -182,
                  top: -126,
                  child: _BackgroundCircle(
                    size: 286,
                    color: Color(0xFF347771),
                    ringWidth: 70,
                    outline: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 8,
          top: 0,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),

        // Login's dot grid, verbatim. A centred 4x4 grid only reaches ~51pt
        // from its middle, so a 128pt circle (radius 64) would hide all 16
        // dots. Sinking it so its lower half sits behind the circle instead:
        // the circle's top edge is 44 + 128 = 172pt up, and half the 84pt grid
        // is 42, so bottom: 130 leaves the top half of the diamond showing
        // above the circle.
        const Positioned(
          left: 0,
          right: -40,
          bottom: 110,
          child: Center(child: _DotGrid()),
        ),

        // IMAGE PLACEHOLDER: replace _HeroLockPlaceholder with the
        // circular lock-icon image once the asset is available. Sits fully
        // inside the green rather than hanging over the content below.
        const Positioned(bottom: 44, child: _HeroLockPlaceholder()),
      ],
    ),
  );
}

class _HeroLockPlaceholder extends StatelessWidget {
  const _HeroLockPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    width: 128,
    height: 128,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .14),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: const Icon(
      Icons.lock_outline_rounded,
      color: Color(0xFF14746E),
      size: 86,
    ),
  );
}

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  /// Verbatim copy of the login header's dot grid: 4x4, 14pt dots on a 21pt
  /// pitch, rotated 45 degrees.
  @override
  Widget build(BuildContext context) {
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

class _InfoLockIcon extends StatelessWidget {
  const _InfoLockIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: const BoxDecoration(
      color: Color(0xFFDCEFEB),
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.lock_outline_rounded,
      color: Color(0xFF16847D),
      size: 17,
    ),
  );
}

class _BackgroundCircle extends StatelessWidget {
  const _BackgroundCircle({
    required this.size,
    required this.color,
    this.ringWidth,
    this.outline,
  });

  final double size;
  final Color color;

  /// When set, the circle is stroked as a ring of this thickness with a
  /// transparent middle instead of being filled.
  final double? ringWidth;

  /// When set, a soft white hairline of this thickness is drawn just outside
  /// the shape, whether it is filled or a ring. The colour matches the
  /// decorative circles on the login screen.
  final double? outline;

  @override
  Widget build(BuildContext context) {
    final ring = ringWidth;
    final shape = Container(
      width: size,
      height: size,
      decoration: ring == null
          ? BoxDecoration(color: color, shape: BoxShape.circle)
          : ShapeDecoration(
              shape: CircleBorder(
                side: BorderSide(color: color, width: ring),
              ),
            ),
    );

    final outlineWidth = outline;
    if (outlineWidth == null) return shape;

    // A slightly larger circle sitting behind the shape. Both are centred by
    // the Stack, which keeps the outline concentric and leaves the ring's hole
    // untouched.
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size + outlineWidth * 2,
          height: size + outlineWidth * 2,
          decoration: ShapeDecoration(
            shape: CircleBorder(
              // Same translucent white hairline the login screen uses for its
              // decorative circles, so both headers read identically.
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: outlineWidth,
              ),
            ),
          ),
        ),
        shape,
      ],
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 43)
    ..quadraticBezierTo(
      size.width * .5,
      size.height + 27,
      size.width,
      size.height - 40,
    )
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
