import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Primary animated button with soft shadow and press scale.
class PrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;
  final IconData? icon;
  final double height;
  final double? width;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.height = 56,
    this.width,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed != null) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onPressed != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? DesignTokens.brownPrimary;
    final fg = widget.foregroundColor ?? DesignTokens.creamBg;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: Container(
            height: widget.height,
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.s24),
            decoration: BoxDecoration(
              color: widget.onPressed != null ? bg : bg.withAlpha(120),
              borderRadius: DesignTokens.brPill,
              boxShadow: widget.onPressed != null ? DesignTokens.shadowPill : null,
            ),
            alignment: Alignment.center,
            child: widget.child ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: fg, size: 22),
                      const SizedBox(width: DesignTokens.s8),
                    ],
                    if (widget.label != null)
                      Text(
                        widget.label!,
                        style: TextStyle(
                          color: fg,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

/// Secondary outlined / soft-tint button.
class SecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final double height;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.height = 48,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: DesignTokens.brownPrimary, width: 2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.s20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: DesignTokens.brownPrimary),
              const SizedBox(width: DesignTokens.s8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: DesignTokens.brownPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill chip to display stats (Coins, Stars, Streak).
class StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final VoidCallback? onTap;

  const StatChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.s12,
          vertical: DesignTokens.s8,
        ),
        decoration: BoxDecoration(
          color: DesignTokens.creamSurface,
          borderRadius: DesignTokens.brPill,
          boxShadow: DesignTokens.shadowSoft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: DesignTokens.s4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: DesignTokens.brownDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Difficulty indicator chip (Easy / Medium / Hard / Expert / Boss)
class DifficultyChip extends StatelessWidget {
  final int level;

  const DifficultyChip({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final isBoss = level % 10 == 0;
    final label = isBoss
        ? 'BOSS'
        : (level <= 10
            ? 'EASY'
            : (level <= 30
                ? 'MEDIUM'
                : (level <= 60 ? 'HARD' : 'EXPERT')));

    final bg = isBoss
        ? DesignTokens.errorRed
        : (level <= 10
            ? DesignTokens.successGreen
            : (level <= 30
                ? DesignTokens.hintBlue
                : (level <= 60 ? DesignTokens.accentAmber : DesignTokens.brownPrimary)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DesignTokens.brPill,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
