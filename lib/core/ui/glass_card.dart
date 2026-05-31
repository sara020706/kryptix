import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final bool shimmer;
  final VoidCallback? onTap;

  const GlassCard({
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.shadows,
    this.shimmer = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);

    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B), // Solid premium dark container color
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.06), // Premium high-contrast thin border
          width: 1,
        ),
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }
}

