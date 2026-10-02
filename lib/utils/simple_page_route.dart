import 'package:flutter/material.dart';

Route<T> simpleFadeRoute<T>(WidgetBuilder builder) {
  const duration = Duration(milliseconds: 180);

  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
