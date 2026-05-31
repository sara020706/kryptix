import 'package:flutter/material.dart';
import 'dart:async';

enum KryptixToastType { success, error, info, warning }

class KryptixToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    KryptixToastType type = KryptixToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => _KryptixToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _KryptixToastWidget extends StatefulWidget {
  final String message;
  final KryptixToastType type;
  final VoidCallback onDismiss;

  const _KryptixToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_KryptixToastWidget> createState() => _KryptixToastWidgetState();
}

class _KryptixToastWidgetState extends State<_KryptixToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _iconColor {
    switch (widget.type) {
      case KryptixToastType.success:
        return const Color(0xFF4CAF50);
      case KryptixToastType.error:
        return const Color(0xFFffb4ab);
      case KryptixToastType.warning:
        return const Color(0xFFFFB74D);
      case KryptixToastType.info:
        return const Color(0xFFadc7ff);
    }
  }

  Color get _glowColor {
    switch (widget.type) {
      case KryptixToastType.success:
        return const Color(0xFF4CAF50).withOpacity(0.3);
      case KryptixToastType.error:
        return const Color(0xFFffb4ab).withOpacity(0.3);
      case KryptixToastType.warning:
        return const Color(0xFFFFB74D).withOpacity(0.3);
      case KryptixToastType.info:
        return const Color(0xFFadc7ff).withOpacity(0.3);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case KryptixToastType.success:
        return Icons.check_circle_outline_rounded;
      case KryptixToastType.error:
        return Icons.error_outline_rounded;
      case KryptixToastType.warning:
        return Icons.warning_amber_rounded;
      case KryptixToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF201f1f),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _iconColor.withOpacity(0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _glowColor,
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                    const BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_icon, color: _iconColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: const Color(0xFFe5e2e1),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
