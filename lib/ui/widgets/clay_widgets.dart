import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/folio_theme.dart';

// ─── Inner-shadow painter ────────────────────────────────────────────────────
// Flutter's BoxShadow can't be inset, so clay's "inflated" look (bright rim
// top-left, soft dark edge bottom-right) is painted here: blurred copies of
// the outside of the shape are drawn, clipped to the shape.

class ClayPainter extends CustomPainter {
  final List<ClayInner> inner;
  final double radius;
  final bool circle;

  const ClayPainter({
    required this.inner,
    required this.radius,
    this.circle = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (inner.isEmpty || size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = circle ? size.shortestSide / 2 : radius;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    canvas.save();
    canvas.clipRRect(rrect);
    for (final s in inner) {
      final reach = s.blur * 2 + math.max(s.offset.dx.abs(), s.offset.dy.abs());
      final ring = Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(reach)),
        Path()..addRRect(rrect.shift(s.offset)),
      );
      canvas.drawPath(
        ring,
        Paint()
          ..color = s.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ClayPainter old) =>
      old.radius != radius || old.circle != circle || old.inner != inner;
}

// ─── ClaySurface (internal building block) ───────────────────────────────────

class ClaySurface extends StatelessWidget {
  final Widget? child;
  final double radius;
  final bool circle;
  final Color color;
  final Gradient? gradient;
  final List<BoxShadow> drop;
  final List<ClayInner> inner;
  final Border? border;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const ClaySurface({
    super.key,
    this.child,
    required this.radius,
    this.circle = false,
    required this.color,
    this.gradient,
    this.drop = const [],
    this.inner = const [],
    this.border,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bw = border?.top.width ?? 0;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        border: border,
        boxShadow: drop,
      ),
      child: CustomPaint(
        foregroundPainter: ClayPainter(
          inner: inner,
          radius: math.max(0, radius - bw),
          circle: circle,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ─── ClayBox ─────────────────────────────────────────────────────────────────
/// A clay container: white "inflated" surface with a floating shadow.
/// [pressed] gives the carved-in look, [flat] removes all depth.
class ClayBox extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool pressed;
  final bool flat;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? overrideColor;
  final ClayDepth depth;

  const ClayBox({
    super.key,
    this.child,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.pressed = false,
    this.flat = false,
    this.width,
    this.height,
    this.onTap,
    this.overrideColor,
    this.depth = ClayDepth.md,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final d = theme.isDark;

    final box = ClaySurface(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      radius: borderRadius,
      color: overrideColor ?? theme.cardBg,
      border: flat ? null : theme.clayBorder,
      drop: (flat || pressed) ? const [] : ClayShadows.drop(d, depth),
      inner: flat
          ? const []
          : pressed
              ? ClayShadows.pressedInner(d, depth)
              : ClayShadows.inner(d, depth),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: box);
    }
    return box;
  }
}

// ─── ClayInset ───────────────────────────────────────────────────────────────
/// Carved-in well, used behind text fields.
class ClayInset extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const ClayInset({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return ClaySurface(
      radius: borderRadius,
      color: theme.isDark ? theme.bg : const Color(0xFFF6F8FC),
      inner: ClayShadows.pressedInner(theme.isDark, ClayDepth.md),
      padding: padding,
      child: child,
    );
  }
}

// ─── ClayButton ──────────────────────────────────────────────────────────────
/// Animated clay button with a squish-down press effect.
class ClayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool filled; // accent-gradient variant

  const ClayButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.filled = false,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.94)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final d = theme.isDark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final isPressed = _ctrl.value > 0.5;
            if (widget.filled) {
              return ClaySurface(
                radius: widget.borderRadius,
                color: theme.accent,
                gradient: theme.accentGradient,
                drop: isPressed
                    ? ClayShadows.pressed(d)
                    : ClayShadows.accentDrop(d),
                inner: ClayShadows.accentInner(d),
                padding: widget.padding,
                child: child,
              );
            }
            return ClaySurface(
              radius: widget.borderRadius,
              color: theme.cardBg,
              border: theme.clayBorder,
              drop: isPressed ? const [] : ClayShadows.drop(d, ClayDepth.sm),
              inner: isPressed
                  ? ClayShadows.pressedInner(d, ClayDepth.sm)
                  : ClayShadows.inner(d, ClayDepth.sm),
              padding: widget.padding,
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── ClayIconButton ──────────────────────────────────────────────────────────
class ClayIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool active;
  final bool filled; // accent-gradient variant (primary round action)
  final String? tooltip;

  const ClayIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 48,
    this.active = false,
    this.filled = false,
    this.tooltip,
  });

  @override
  State<ClayIconButton> createState() => _ClayIconButtonState();
}

class _ClayIconButtonState extends State<ClayIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.93)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final d = theme.isDark;

    final btn = GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            if (widget.filled) {
              final down = _ctrl.value > 0.5;
              return ClaySurface(
                width: widget.size,
                height: widget.size,
                circle: true,
                radius: widget.size / 2,
                color: theme.accent,
                gradient: theme.accentGradient,
                drop: down ? ClayShadows.pressed(d) : ClayShadows.accentDrop(d),
                inner: ClayShadows.accentInner(d),
                child: Center(
                  child: Icon(widget.icon,
                      color: Colors.white, size: widget.size * 0.46),
                ),
              );
            }
            final pressed = _ctrl.value > 0.5 || widget.active;
            return ClaySurface(
              width: widget.size,
              height: widget.size,
              circle: true,
              radius: widget.size / 2,
              color: widget.active ? theme.accentSoft : theme.cardBg,
              border: theme.clayBorder,
              drop: pressed ? const [] : ClayShadows.drop(d, ClayDepth.sm),
              inner: pressed
                  ? ClayShadows.pressedInner(d, ClayDepth.sm)
                  : ClayShadows.inner(d, ClayDepth.sm),
              child: Center(
                child: Icon(
                  widget.icon,
                  color: widget.active ? theme.accent : theme.textSub,
                  size: widget.size * 0.44,
                ),
              ),
            );
          },
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

// ─── ClayTextField ───────────────────────────────────────────────────────────
class ClayTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  const ClayTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return ClayInset(
      borderRadius: 18,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textInputAction: TextInputAction.done,
        style: TextStyle(
          color: theme.text,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          counterStyle: TextStyle(color: theme.textSub, fontSize: 11),
          labelStyle:
              TextStyle(color: theme.textSub, fontWeight: FontWeight.w600),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: theme.textSub)
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─── ClayChip ────────────────────────────────────────────────────────────────
class ClayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const ClayChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final d = theme.isDark;
    return GestureDetector(
      onTap: onTap,
      child: ClaySurface(
        radius: 24,
        color: selected ? theme.accent : theme.cardBg,
        gradient: selected ? theme.accentGradient : null,
        border: selected ? null : theme.clayBorder,
        drop: selected
            ? ClayShadows.pressed(d)
            : ClayShadows.drop(d, ClayDepth.sm),
        inner: selected
            ? ClayShadows.accentInner(d)
            : ClayShadows.inner(d, ClayDepth.sm),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : theme.textSub,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Theme toggle (same button on every screen header) ───────────────────────
class ClayThemeToggle extends StatelessWidget {
  const ClayThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return GestureDetector(
      onLongPress: () {
        // Long press = back to automatic (time-based) theme
        theme.setAuto();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Theme set to Auto (time-based)')),
        );
      },
      child: ClayIconButton(
        icon: theme.isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
        active: !theme.isAuto,
        tooltip:
            theme.isAuto ? 'Auto (long-press to reset)' : 'Manual override',
        onTap: () => theme.isDark ? theme.setDark(false) : theme.setDark(true),
        size: 44,
      ),
    );
  }
}

// ─── Shared titles: Fredoka + one accent-coloured letter ─────────────────────
/// The look used for the app's big titles. Always the same font, weight and
/// accent-letter effect, in light and dark mode, on every screen:
///   "Folio" -> accent "i"      "Tasks" / "New task" -> accent "k"
/// The accent colour is pink in light mode and cyan-blue in dark mode.
class AccentTitle extends StatelessWidget {
  final String text;
  final String accent; // the letter to colour (last occurrence)
  final double size;
  final Color? color;

  const AccentTitle({
    super.key,
    required this.text,
    required this.accent,
    this.size = 34,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final base = FolioFonts.display(
      color: color ?? theme.text,
      size: size,
      letterSpacing: -size * 0.02,
    );
    final i = text.toLowerCase().lastIndexOf(accent.toLowerCase());
    if (i < 0) {
      return Text(text, style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
              text: text.substring(i, i + 1),
              style: base.copyWith(color: theme.accent)),
          TextSpan(text: text.substring(i + 1)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class FolioWordmark extends StatelessWidget {
  final double size;
  const FolioWordmark({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) =>
      AccentTitle(text: 'Folio', accent: 'i', size: size);
}

class TasksTitle extends StatelessWidget {
  final double size;
  const TasksTitle({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) =>
      AccentTitle(text: 'Tasks', accent: 'k', size: size);
}

// ─── Text prompt dialog (rename / new folder) ────────────────────────────────
/// Asks for one line of text. Returns the trimmed text, or null if cancelled
/// or left empty.
///
/// The TextEditingController lives inside the dialog's own State and is
/// disposed with it. Creating the controller in the caller and disposing it
/// right after `await showDialog` breaks the dialog while it's still
/// animating closed, which is what caused the red `_dependents.isEmpty`
/// screen after renaming.
Future<String?> showClayTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  IconData? icon,
  String initialText = '',
  String confirmLabel = 'Save',
  String? Function(String text)? validator,
  int? maxLength,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ClayPromptDialog(
      title: title,
      label: label,
      icon: icon,
      initialText: initialText,
      confirmLabel: confirmLabel,
      validator: validator,
      maxLength: maxLength,
    ),
  );
}

class _ClayPromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final IconData? icon;
  final String initialText;
  final String confirmLabel;
  final String? Function(String text)? validator;
  final int? maxLength;

  const _ClayPromptDialog({
    required this.title,
    required this.label,
    required this.icon,
    required this.initialText,
    required this.confirmLabel,
    required this.validator,
    required this.maxLength,
  });

  @override
  State<_ClayPromptDialog> createState() => _ClayPromptDialogState();
}

class _ClayPromptDialogState extends State<_ClayPromptDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.selection = TextSelection(
        baseOffset: 0, extentOffset: widget.initialText.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final error = widget.validator?.call(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return AlertDialog(
      backgroundColor: theme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.title,
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClayTextField(
            controller: _controller,
            label: widget.label,
            prefixIcon: widget.icon,
            autofocus: true,
            maxLength: widget.maxLength,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 6),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: TextStyle(
                  color: theme.textSub, fontWeight: FontWeight.w700)),
        ),
        ClayButton(
          filled: true,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          onTap: _submit,
          child: Text(widget.confirmLabel,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

/// Width/height of a dashboard folder tile; grows with the user's font size
/// (up to the app-wide cap) so the text never overflows the tile.
double folderTileSize(BuildContext context) =>
    120 * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4).toDouble();
