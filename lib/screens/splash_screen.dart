import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'request_account_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. DESIGN TOKENS
// ═════════════════════════════════════════════════════════════════════════════
/// Every colour used by the splash + welcome screens.
///
/// NOTE: these were sampled from a *camera recording of a phone screen*, so
/// they are very close but not guaranteed to be the exact Figma values.
/// If you have the real hex codes, change them here – nothing else needs to
/// be touched.
class SplashColors {
  SplashColors._();

  /// Splash background.
  static const Color splashBackground = Color(0xFF0F4844);

  /// Filled "Log in" button.
  static const Color primaryButton = Color(0xFF0F4844);

  /// "Welcome!" title, "Create account" label and its outline.
  static const Color title = Color(0xFF0F4844);
  static const Color welcomeTitle = Colors.black;

  /// Grey body copy.
  static const Color body = Color(0xFF585870);

  /// Welcome page background.
  static const Color background = Colors.white;
}

class AppAssets {
  AppAssets._();

  /// Coloured logo mark that appears inside the white circle
  /// (tight-cropped, transparent PNG – export from Figma @3x).
  static const String logo = 'assets/images/Lendy.png';

  /// The two kids swapping items (tight-cropped PNG, ~284 x 243 aspect).
  static const String welcomeIllustration = 'assets/images/welcome_img.png';
}

/// Inter is the typeface in the video (verified by matching the rendered
/// width of every string against Inter's metrics).
///
/// All sizes are passed in already scaled to the current screen.
class AppTextStyles {
  AppTextStyles._();

  /// "Lendy" wordmark on the splash.
  static TextStyle brand(double size) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: Colors.white,
  );

  /// "Welcome!"
  static TextStyle welcomeTitle(double size) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: SplashColors.welcomeTitle,
  );

  /// Sub-title and the "Borrow the things you need…" tagline.
  static TextStyle body(double size) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: 1.17,
    color: SplashColors.body,
  );

  /// "Log in" / "Create account".
  static TextStyle button(double size, Color color) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. BOUNCE CURVE
// ═════════════════════════════════════════════════════════════════════════════
/// The "fall + bounce" motion of the splash circle.
///
/// It is a damped oscillation that goes from 0 to 1 but *overshoots* on the
/// way (≈ 1.5 → 0.84 → 1.05 → 1.0), exactly like the circle in the reference
/// video which drops past the centre, springs back up and settles.
///
/// The output is deliberately allowed to leave the 0..1 range, so it must be
/// used with an unclamped interpolation (`a + (b - a) * t`) – never with
/// `Tween.clamp` / `Interval`.
///
/// Constants were fitted to the per-frame position of the circle in the video.
class BouncyDropCurve extends Curve {
  const BouncyDropCurve({
    this.damping = 5.64,
    this.frequency = 15.12,
    this.launchSpeed = 0.683,
    this.seconds = 0.9,
  });

  /// How quickly the oscillation dies out (higher = fewer bounces).
  final double damping;

  /// Angular frequency in rad/s (higher = faster bounces).
  final double frequency;

  /// Extra initial velocity that makes the first overshoot bigger.
  final double launchSpeed;

  /// The real-time length `t = 1.0` maps to. Keep equal to the controller
  /// duration so the constants above stay in seconds.
  final double seconds;

  @override
  double transformInternal(double t) {
    final u = t * seconds;
    final decay = math.exp(-damping * u);
    return 1 -
        decay *
            (math.cos(frequency * u) - launchSpeed * math.sin(frequency * u));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. SPLASH SCREEN
// ═════════════════════════════════════════════════════════════════════════════
// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (logical px on a 393 x 852 reference screen, measured from the
// reference video). Everything is multiplied by `s = min(w/393, h/852)` at
// runtime so proportions stay identical on every device.
// ─────────────────────────────────────────────────────────────────────────────
const double _refWidth = 393;
const double _refHeight = 852;

const double _startDiameter = 38; // small circle at the top
const double _restDiameter = 116; // big circle resting in the centre
const double _finalDiameter = 70; // circle inside the "logo + Lendy" lockup
const double _startYFraction = 0.300; // start height as a fraction of screen h
const double _logoScale = 0.85; // logo height ÷ circle diameter

const double _brandFontSize = 49;
const double _lockupGap = 19; // circle → text
const double _lockupTrailing =
    12; // the reference lockup sits ~6px left of centre
const double _brandDy =
    4.5; // text cap-height centre sits slightly below circle centre

// ─────────────────────────────────────────────────────────────────────────────
// Timeline (matches the video, t = 0 when the small circle appears)
//
//   0.30 – 1.40  circle falls, grows, bounces and settles in the centre
//   1.55 – 1.85  logo fades in inside the circle
//   2.05 – 2.55  circle shrinks + slides left, "Lendy" slides in from the right
//   2.90         cross-fade to the welcome page
// ─────────────────────────────────────────────────────────────────────────────
const Duration _pauseBeforeDrop = Duration(milliseconds: 300);
const Duration _dropDuration = Duration(milliseconds: 1100);
const Duration _pauseAfterDrop = Duration(milliseconds: 150);
const Duration _logoFadeDuration = Duration(milliseconds: 300);
const Duration _pauseAfterLogo = Duration(milliseconds: 200);
const Duration _lockupDuration = Duration(milliseconds: 500);
const Duration _pauseAfterLockup = Duration(milliseconds: 350);

double _lerp(double a, double b, double t) => a + (b - a) * t;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _dropController;
  late final AnimationController _logoController;
  late final AnimationController _lockupController;

  late final Animation<double> _drop; // 0 → 1.5 → 0.84 → 1.05 → 1 (overshoots!)
  late final Animation<double> _logo; // 0 → 1
  late final Animation<double> _lockup; // 0 → 1

  @override
  void initState() {
    super.initState();

    _dropController = AnimationController(vsync: this, duration: _dropDuration);
    _logoController = AnimationController(
      vsync: this,
      duration: _logoFadeDuration,
    );
    _lockupController = AnimationController(
      vsync: this,
      duration: _lockupDuration,
    );

    _drop = CurvedAnimation(
      parent: _dropController,
      curve: const BouncyDropCurve(),
    );
    _logo = CurvedAnimation(parent: _logoController, curve: Curves.easeInOut);
    _lockup = CurvedAnimation(
      parent: _lockupController,
      curve: Curves.easeOutCubic,
    );

    _play();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Avoid the logo "popping" in when it starts fading.
    precacheImage(
      const AssetImage(AppAssets.logo),
      context,
      onError: (_, _) {},
    );
  }

  Future<void> _play() async {
    try {
      await Future<void>.delayed(_pauseBeforeDrop);
      if (!mounted) return;

      await _dropController.forward().orCancel;
      await Future<void>.delayed(_pauseAfterDrop);
      if (!mounted) return;

      await _logoController.forward().orCancel;
      await Future<void>.delayed(_pauseAfterLogo);
      if (!mounted) return;

      await _lockupController.forward().orCancel;
      await Future<void>.delayed(_pauseAfterLockup);
      if (!mounted) return;

      _goToWelcome();
    } on TickerCanceled {
      // The screen was disposed while animating – nothing to do.
    }
  }

  void _goToWelcome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => const WelcomeScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _dropController.dispose();
    _logoController.dispose();
    _lockupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: SplashColors.splashBackground,
        body: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final s = math.min(w / _refWidth, h / _refHeight);

            // Measure the wordmark once per layout (not per animation frame).
            final brandStyle = AppTextStyles.brand(_brandFontSize * s);
            final painter = TextPainter(
              text: TextSpan(text: 'Lendy', style: brandStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();
            final textW = painter.width;
            final textH = painter.height;
            painter.dispose();

            final startD = _startDiameter * s;
            final restD = _restDiameter * s;
            final endD = _finalDiameter * s;

            // Final lockup:  ( ◯ )  Lendy   – centred as a group.
            final lockupW = endD + _lockupGap * s + textW + _lockupTrailing * s;
            final lockupLeft = (w - lockupW) / 2;
            final endCenterX = lockupLeft + endD / 2;
            final textEndLeft = lockupLeft + endD + _lockupGap * s;

            final centerY = h / 2;
            final startY = h * _startYFraction;

            return AnimatedBuilder(
              animation: Listenable.merge([_drop, _logo, _lockup]),
              builder: (context, _) {
                final drop = _drop.value; // may exceed 1 (overshoot)
                final q = _lockup.value;

                // While falling, size is tied to height (the circle "comes
                // towards the camera" as it drops), so it grows to ~150 at
                // the lowest point of the bounce and settles at 116.
                final fallDiameter = _lerp(startD, restD, drop);
                final diameter = _lerp(fallDiameter, endD, q);

                final cx = _lerp(w / 2, endCenterX, q);
                final cy = _lerp(startY, centerY, drop);

                // The wordmark starts just off the right edge and is simply
                // clipped by the screen while it slides in.
                final textLeft = _lerp(w, textEndLeft, q);

                return SizedBox.expand(
                  child: Stack(
                    children: [
                      Positioned(
                        left: textLeft,
                        top: centerY - textH / 2 + _brandDy * s,
                        child: Text(
                          'Lendy',
                          style: brandStyle,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      Positioned(
                        left: cx - diameter / 2,
                        top: cy - diameter / 2,
                        width: diameter,
                        height: diameter,
                        child: _LogoBadge(
                          diameter: diameter,
                          logoOpacity: _logo.value,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// White circle with the logo fading in inside it.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.diameter, required this.logoOpacity});

  final double diameter;
  final double logoOpacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Opacity(
          opacity: logoOpacity.clamp(0.0, 1.0),
          child: Image.asset(
            AppAssets.logo,
            height: diameter * _logoScale,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            // Keeps the app running until you drop the real asset in.
            errorBuilder: (_, _, _) => Icon(
              Icons.menu_book_rounded,
              size: diameter * 0.5,
              color: SplashColors.splashBackground,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WELCOME SCREEN
// ═════════════════════════════════════════════════════════════════════════════
// Text sizes (Inter)
const double _titleSize = 36; // "Welcome!"  – Bold 700
const double _bodySize = 13.6; // sub-title + tagline – Regular 400
const double _buttonFontSize = 19; // SemiBold 600

// Header: title + sub-title (slides DOWN from the top edge)
const double _headerTop = 143.3;
const double _titleToBody = 10.8;
const double _headerBottom = 245.0; // used as the off-screen start distance

// Illustration + tagline (slides UP from the bottom edge)
const double _illustrationTop = 270.3;
const double _illustrationWidth = 400;
const double _illustrationHeight = 340;
const double _illustrationToTagline = 42;

// Buttons (slide UP from the bottom edge)
const double _sideMargin = 48;
const double _bottomMargin = 88.6;
const double _buttonHeight = 46;
const double _buttonGap = 16;
const double _buttonsBlockHeight = _buttonHeight * 2 + _buttonGap;

// Entrance animation (timing from the video: white page first, content starts
// ~0.4 s later and eases out over ~0.5 s).
const Duration _entranceDelay = Duration(milliseconds: 400);
const Duration _entranceDuration = Duration(milliseconds: 500);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onLogin, this.onRequestAccount});

  final VoidCallback? onLogin;
  final VoidCallback? onRequestAccount;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _entranceDuration);
    _slide = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad);

    _startTimer = Timer(_entranceDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: SplashColors.background,
        body: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final s = math.min(w / _refWidth, h / _refHeight);

            return Stack(
              children: [
                // Illustration + tagline – enters from below.
                Positioned(
                  top: _illustrationTop * s,
                  left: 0,
                  right: 0,
                  child: _SlideIn(
                    animation: _slide,
                    distance: h - _illustrationTop * s,
                    child: _IllustrationBlock(s: s),
                  ),
                ),

                // Title + sub-title – enters from above.
                Positioned(
                  top: _headerTop * s,
                  left: 0,
                  right: 0,
                  child: _SlideIn(
                    animation: _slide,
                    distance: -_headerBottom * s,
                    child: _Header(s: s),
                  ),
                ),

                // Buttons – enter from below and paint on top of the artwork
                // (in the video the "Log in" pill overlaps the illustration
                // while it is still travelling).
                Positioned(
                  left: _sideMargin * s,
                  right: _sideMargin * s,
                  bottom: _bottomMargin * s,
                  child: _SlideIn(
                    animation: _slide,
                    distance: (_bottomMargin + _buttonsBlockHeight) * s,
                    child: _Buttons(
                      s: s,
                      onLogin:
                          widget.onLogin ??
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                      onRequestAccount:
                          widget.onRequestAccount ??
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RequestAccountScreen(),
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Translates [child] vertically from `distance` px away to its resting
/// position as [animation] goes 0 → 1. The screen edge clips it while it is
/// still outside the viewport.
class _SlideIn extends StatelessWidget {
  const _SlideIn({
    required this.animation,
    required this.distance,
    required this.child,
  });

  final Animation<double> animation;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, distance * (1 - animation.value)),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.s});

  final double s;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome!',
          textAlign: TextAlign.center,
          style: AppTextStyles.welcomeTitle(_titleSize * s),
        ),
        SizedBox(height: _titleToBody * s),
        // Explicit line breaks so the wrap is identical to the design on
        // every device (the design wraps into exactly these three lines).
        Text(
          'We are glad to have you here.\n'
          'Let’s make borrowing simple\n'
          'and convenient.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(_bodySize * s),
        ),
      ],
    );
  }
}

class _IllustrationBlock extends StatelessWidget {
  const _IllustrationBlock({required this.s});

  final double s;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _illustrationWidth * s,
          height: _illustrationHeight * s,
          child: Image.asset(
            AppAssets.welcomeIllustration,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            // Keeps the app running until you drop the real asset in.
            errorBuilder: (_, _, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F6),
                borderRadius: BorderRadius.circular(24 * s),
              ),
              child: Icon(
                Icons.image_outlined,
                size: 48 * s,
                color: SplashColors.body,
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -_illustrationToTagline * s),
          child: Text(
            'Borrow the things you need,\n'
            'share with trust.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(_bodySize * s),
          ),
        ),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.s, this.onLogin, this.onRequestAccount});

  final double s;
  final VoidCallback? onLogin;
  final VoidCallback? onRequestAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PillButton(
          label: 'Log in',
          filled: true,
          height: _buttonHeight * s,
          fontSize: _buttonFontSize * s,
          onPressed: onLogin ?? () {},
        ),
        SizedBox(height: _buttonGap * s),
        _PillButton(
          label: 'Request Account',
          filled: false,
          height: _buttonHeight * s,
          fontSize: _buttonFontSize * s,
          onPressed: onRequestAccount ?? () {},
        ),
      ],
    );
  }
}

/// Fully-rounded button: filled teal ("Log in") or 1px outlined
/// ("Create account").
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.height,
    required this.fontSize,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final double height;
  final double fontSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : SplashColors.title;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: filled ? SplashColors.primaryButton : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : const BorderSide(color: SplashColors.title, width: 1),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.button(fontSize, foreground),
            ),
          ),
        ),
      ),
    );
  }
}
