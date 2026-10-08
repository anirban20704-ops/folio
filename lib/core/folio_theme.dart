import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Claymorphism Color Palette ───────────────────────────────────────────────
// Values follow the "Claymorphism Light / Dark" tokens of the Folio UI system.

class FolioColors {
  // Day (Light) — 06:00 → 19:00
  static const Color dayBg = Color(0xFFF0F3F9);
  static const Color dayCard = Color(0xFFFFFFFF);
  static const Color dayClayShadow = Color(0xFFA0AFC8); // rgb(160,175,200)
  static const Color dayText = Color(0xFF1E293B);
  static const Color dayTextSub = Color(0xFF64748B);
  static const Color dayAccent = Color(0xFFEC4899);
  static const Color dayAccentStart = Color(0xFFF43F5E);
  static const Color dayAccentEnd = Color(0xFFFB7185);
  static const Color dayAccentGlow = Color(0xFFF43F5E);
  static const Color dayAccentSoft = Color(0xFFFCE7F3);

  // Night (Dark) — 19:00 → 06:00
  static const Color nightBg = Color(0xFF0B0F19);
  static const Color nightCard = Color(0xFF1E293B);
  static const Color nightClayShadow = Color(0xFF000000);
  static const Color nightText = Color(0xFFF8FAFC);
  static const Color nightTextSub = Color(0xFF94A3B8);
  static const Color nightAccent = Color(0xFF06B6D4);
  static const Color nightAccentStart = Color(0xFF06B6D4);
  static const Color nightAccentEnd = Color(0xFF3B82F6);
  static const Color nightAccentGlow = Color(0xFF06B6D4);
  static const Color nightAccentSoft = Color(0xFF123447);
}

// ─── Display font ─────────────────────────────────────────────────────────────
// Chunky, rounded Fredoka for the "Folio" wordmark and the Tasks headings;
// everything else stays in Nunito.
class FolioFonts {
  static TextStyle display({
    required Color color,
    required double size,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = -0.5,
  }) =>
      GoogleFonts.fredoka(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.05,
      );
}

// ─── Clay depth presets ──────────────────────────────────────────────────────

enum ClayDepth { sm, md, lg }

/// One inner (inset) shadow, painted inside a clay surface by ClayPainter.
class ClayInner {
  final Color color;
  final Offset offset;
  final double blur;
  const ClayInner(this.color, this.offset, this.blur);
}

class ClayShadows {
  /// Outer floating shadow of a clay object.
  static List<BoxShadow> drop(bool isDark, ClayDepth d) {
    final c = isDark ? FolioColors.nightClayShadow : FolioColors.dayClayShadow;
    switch (d) {
      case ClayDepth.sm:
        return [
          BoxShadow(
              color: c.withValues(alpha: isDark ? 0.60 : 0.30),
              offset: const Offset(6, 10),
              blurRadius: 16)
        ];
      case ClayDepth.md:
        return [
          BoxShadow(
              color: c.withValues(alpha: isDark ? 0.65 : 0.35),
              offset: const Offset(12, 16),
              blurRadius: 24)
        ];
      case ClayDepth.lg:
        return [
          BoxShadow(
              color: c.withValues(alpha: isDark ? 0.85 : 0.40),
              offset: const Offset(18, 24),
              blurRadius: 36)
        ];
    }
  }

  /// Inflated look: soft dark edge bottom-right, bright rim top-left.
  static List<ClayInner> inner(bool isDark, ClayDepth d) {
    final dark = Colors.black;
    final light = Colors.white;
    switch (d) {
      case ClayDepth.sm:
        return [
          ClayInner(dark.withValues(alpha: isDark ? 0.40 : 0.05),
              const Offset(-3, -3), 8),
          ClayInner(light.withValues(alpha: isDark ? 0.10 : 0.90),
              const Offset(3, 3), 8),
        ];
      case ClayDepth.md:
        return [
          ClayInner(dark.withValues(alpha: isDark ? 0.40 : 0.05),
              const Offset(-6, -6), 12),
          ClayInner(light.withValues(alpha: isDark ? 0.12 : 0.90),
              const Offset(6, 6), 12),
        ];
      case ClayDepth.lg:
        return [
          ClayInner(dark.withValues(alpha: isDark ? 0.50 : 0.06),
              const Offset(-8, -8), 16),
          ClayInner(light.withValues(alpha: isDark ? 0.15 : 0.95),
              const Offset(8, 8), 16),
        ];
    }
  }

  /// Pressed / carved-in look (inputs, active states).
  static List<ClayInner> pressedInner(bool isDark, ClayDepth d) {
    final big = d != ClayDepth.sm;
    final o = big ? 6.0 : 4.0;
    final b = big ? 12.0 : 8.0;
    if (isDark) {
      return [
        ClayInner(Colors.black.withValues(alpha: big ? 0.60 : 0.50),
            Offset(o, o), b),
        ClayInner(Colors.white.withValues(alpha: 0.08), Offset(-o, -o), b),
      ];
    }
    return [
      ClayInner(FolioColors.dayClayShadow.withValues(alpha: big ? 0.40 : 0.35),
          Offset(o, o), b),
      ClayInner(Colors.white.withValues(alpha: 0.80), Offset(-o, -o), b),
    ];
  }

  /// Glow + volume for accent-filled clay (primary buttons, selected chips).
  static List<BoxShadow> accentDrop(bool isDark) => [
        BoxShadow(
          color: (isDark
                  ? FolioColors.nightAccentGlow
                  : FolioColors.dayAccentGlow)
              .withValues(alpha: isDark ? 0.45 : 0.40),
          offset: const Offset(8, 12),
          blurRadius: isDark ? 22 : 20,
        ),
      ];

  static List<ClayInner> accentInner(bool isDark) => [
        ClayInner(Colors.black.withValues(alpha: isDark ? 0.30 : 0.20),
            const Offset(-4, -4), 8),
        ClayInner(Colors.white.withValues(alpha: isDark ? 0.40 : 0.50),
            const Offset(4, 4), 8),
      ];

  // Drop-shadow-only presets, for the few raw BoxDecoration call sites.
  static List<BoxShadow> raised(bool isDark) => drop(isDark, ClayDepth.md);
  static List<BoxShadow> subtle(bool isDark) => drop(isDark, ClayDepth.sm);
  static List<BoxShadow> pressed(bool isDark) => [
        BoxShadow(
          color: (isDark
                  ? FolioColors.nightClayShadow
                  : FolioColors.dayClayShadow)
              .withValues(alpha: isDark ? 0.5 : 0.25),
          offset: const Offset(3, 5),
          blurRadius: 8,
        ),
      ];
  static List<BoxShadow> inset(bool isDark) => pressed(isDark);
}

// ─── Theme Notifier ───────────────────────────────────────────────────────────

class FolioThemeNotifier extends ChangeNotifier {
  bool? _manualDark; // null = auto-detect by time

  /// True if dark mode should be active.
  /// Auto: dark from 19:00 to 05:59, light from 06:00 to 18:59.
  bool get isDark {
    if (_manualDark != null) return _manualDark!;
    final h = DateTime.now().hour;
    return h < 6 || h >= 19;
  }

  bool get isAuto => _manualDark == null;

  void setDark(bool value) {
    _manualDark = value;
    notifyListeners();
  }

  void setAuto() {
    _manualDark = null;
    notifyListeners();
  }

  // ─── Semantic colours ─────────────────────────────────────────────────────

  /// Page background.
  Color get bg => isDark ? FolioColors.nightBg : FolioColors.dayBg;

  /// Surface colour of clay objects (cards, buttons, fields).
  Color get cardBg => isDark ? FolioColors.nightCard : FolioColors.dayCard;
  Color get text => isDark ? FolioColors.nightText : FolioColors.dayText;
  Color get textSub => isDark ? FolioColors.nightTextSub : FolioColors.dayTextSub;
  Color get accent => isDark ? FolioColors.nightAccent : FolioColors.dayAccent;
  Color get accentSoft =>
      isDark ? FolioColors.nightAccentSoft : FolioColors.dayAccentSoft;
  Color get darkShadow =>
      isDark ? FolioColors.nightClayShadow : FolioColors.dayClayShadow;
  Color get lightShadow => Colors.white;

  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [FolioColors.nightAccentStart, FolioColors.nightAccentEnd]
            : const [FolioColors.dayAccentStart, FolioColors.dayAccentEnd],
      );

  /// Thin bright rim around clay objects.
  Border? get clayBorder => isDark
      ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1)
      : Border.all(color: Colors.white.withValues(alpha: 0.60), width: 2);

  // ─── Shadow shortcuts (outer shadows only) ────────────────────────────────

  List<BoxShadow> get raisedShadow => ClayShadows.raised(isDark);
  List<BoxShadow> get subtleShadow => ClayShadows.subtle(isDark);
  List<BoxShadow> get pressedShadow => ClayShadows.pressed(isDark);
  List<BoxShadow> get insetShadow => ClayShadows.inset(isDark);

  // ─── MaterialThemeData ────────────────────────────────────────────────────

  ThemeData get themeData => isDark ? _nightTheme() : _dayTheme();

  ThemeData _dayTheme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: FolioColors.dayBg,
      colorScheme: const ColorScheme.light(
        primary: FolioColors.dayAccent,
        secondary: FolioColors.dayAccent,
        surface: FolioColors.dayBg,
        onSurface: FolioColors.dayText,
        primaryContainer: FolioColors.dayAccentSoft,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
        bodyColor: FolioColors.dayText,
        displayColor: FolioColors.dayText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FolioColors.dayBg,
        foregroundColor: FolioColors.dayText,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.nunito(
          color: FolioColors.dayText,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: -0.5,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FolioColors.dayCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FolioColors.dayText,
        contentTextStyle: GoogleFonts.nunito(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ThemeData _nightTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: FolioColors.nightBg,
      colorScheme: const ColorScheme.dark(
        primary: FolioColors.nightAccent,
        secondary: FolioColors.nightAccent,
        surface: FolioColors.nightBg,
        onSurface: FolioColors.nightText,
        primaryContainer: FolioColors.nightAccentSoft,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
        bodyColor: FolioColors.nightText,
        displayColor: FolioColors.nightText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FolioColors.nightBg,
        foregroundColor: FolioColors.nightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.nunito(
          color: FolioColors.nightText,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: -0.5,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FolioColors.nightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FolioColors.nightCard,
        contentTextStyle: GoogleFonts.nunito(color: FolioColors.nightText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
