import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/folio_theme.dart';

// ─── NeuBox ───────────────────────────────────────────────────────────────────
/// A neumorphic container that reads FolioThemeNotifier from context.
class NeuBox extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool pressed;  // inset/pressed style
  final bool flat;     // no shadows (for selected tabs, etc.)
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? overrideColor;

  const NeuBox({
    super.key,
    this.child,
    this.borderRadius = 18,
    this.padding,
    this.margin,
    this.pressed = false,
    this.flat = false,
    this.width,
    this.height,
    this.onTap,
    this.overrideColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final bg = overrideColor ?? theme.bg;
    List<BoxShadow> shadows;
    if (flat) {
      shadows = [];
    } else if (pressed) {
      shadows = theme.pressedShadow;
    } else {
      shadows = theme.raisedShadow;
    }

    final box = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: box);
    }
    return box;
  }
}

// ─── NeuButton ────────────────────────────────────────────────────────────────
/// Animated neumorphic button with press-down effect.
class NeuButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool filled; // accent-filled variant

  const NeuButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.filled = false,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) {
    _ctrl.reverse();
    widget.onTap?.call();
  }
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final isPressed = _ctrl.value > 0.5;
            return Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.filled ? theme.accent : theme.bg,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: isPressed
                    ? theme.pressedShadow
                    : theme.raisedShadow,
                gradient: widget.filled
                    ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.accent.withValues(alpha: 0.9),
                    theme.accent,
                  ],
                )
                    : null,
              ),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── NeuIconButton ────────────────────────────────────────────────────────────
class NeuIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool active;
  final String? tooltip;

  const NeuIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 48,
    this.active = false,
    this.tooltip,
  });

  @override
  State<NeuIconButton> createState() => _NeuIconButtonState();
}

class _NeuIconButtonState extends State<NeuIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    final btn = GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final pressed = _ctrl.value > 0.5;
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.active ? theme.accentSoft : theme.bg,
              shape: BoxShape.circle,
              boxShadow: pressed || widget.active
                  ? theme.pressedShadow
                  : theme.subtleShadow,
            ),
            child: Icon(
              widget.icon,
              color: widget.active ? theme.accent : theme.textSub,
              size: widget.size * 0.44,
            ),
          );
        },
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

// ─── NeuTextField ─────────────────────────────────────────────────────────────
class NeuTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final bool autofocus;

  const NeuTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: theme.insetShadow,
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: TextStyle(
          color: theme.text,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.textSub, fontWeight: FontWeight.w600),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: theme.textSub)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─── NeuChip ──────────────────────────────────────────────────────────────────
class NeuChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const NeuChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.accent : theme.bg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected ? theme.pressedShadow : theme.subtleShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : theme.textSub,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
