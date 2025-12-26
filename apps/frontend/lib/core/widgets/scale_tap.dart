import 'package:flutter/material.dart';

/// 🚀 WIDGET TIER 1: Wrapper para interacciones de escala hípica
/// Proporciona un feedback visual sutil (0.98x) al presionar.
class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  final Duration duration;

  const ScaleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 80),
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
