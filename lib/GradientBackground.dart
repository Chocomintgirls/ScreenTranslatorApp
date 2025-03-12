import 'package:flutter/material.dart';


class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.3),
          radius: 1.5,
          colors: [
            Color(0xFF8CA0E0), // Light blue
            Color(0xFF3854AF), // Darker blue
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}