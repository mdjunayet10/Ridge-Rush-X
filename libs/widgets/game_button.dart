import 'package:flutter/material.dart';

class GameButton extends StatefulWidget {
  const GameButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.compact = false,
    this.primary = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool compact;
  final bool primary;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final accent = widget.color ?? const Color(0xFFFFB703);
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 720;
    final height = widget.compact
        ? (desktop ? 54.0 : 48.0)
        : widget.primary
        ? (desktop ? 68.0 : 62.0)
        : (desktop ? 56.0 : 52.0);
    final radius = widget.compact ? 16.0 : 20.0;
    final glow = enabled ? (_hovered ? 0.38 : 0.24) : 0.0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onPressed?.call();
                }
              : null,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            scale: _pressed ? 0.965 : (_hovered ? 1.018 : 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: glow),
                          blurRadius: widget.primary ? 34 : 24,
                          spreadRadius: widget.primary ? 2 : 0,
                          offset: const Offset(0, 8),
                        ),
                        const BoxShadow(
                          color: Color(0xB0000000),
                          blurRadius: 22,
                          offset: Offset(0, 14),
                        ),
                      ]
                    : const [],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: enabled
                        ? [
                            Color.lerp(const Color(0xFF20304B), accent, 0.38)!,
                            const Color(0xFF111827),
                            const Color(0xFF05070C),
                          ]
                        : const [Color(0xFF171C27), Color(0xFF0B0F18)],
                  ),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: enabled
                        ? accent.withValues(alpha: _hovered ? 0.95 : 0.72)
                        : const Color(0xFF303A4D),
                    width: widget.primary ? 2.3 : 1.7,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 16 : 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: enabled ? accent : const Color(0xFF6E7D94),
                          size: widget.primary
                              ? 28
                              : (widget.compact ? 22 : 24),
                        ),
                        SizedBox(width: widget.primary ? 14 : 10),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: enabled
                                ? const Color(0xFFE7FDFF)
                                : const Color(0xFF7D8798),
                            fontSize: widget.primary
                                ? (desktop ? 22 : 20)
                                : widget.compact
                                ? (desktop ? 17 : 15)
                                : (desktop ? 18 : 16),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
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
      ),
    );
  }
}
