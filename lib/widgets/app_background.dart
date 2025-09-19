import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDDE2F0), // もう少しだけ暗くして、さらに落ち着いた感じに
      ),
      child: child,
    );
  }
}