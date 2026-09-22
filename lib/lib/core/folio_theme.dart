import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Neumorphic Color Palette ─────────────────────────────────────────────────

class FolioColors {
  // Day (Light) — 06:00 → 19:00
  static const Color dayBg = Color(0xFFE0E5EC);
  static const Color dayDarkShadow = Color(0xFFA3B1C6);
  static const Color dayLightShadow = Color(0xFFFFFFFF);
  static const Color dayText = Color(0xFF2D3748);
  static const Color dayTextSub = Color(0xFF718096);
  static const Color dayAccent = Color(0xFF673AB7);
  static const Color dayAccentSoft = Color(0xFFEDE7F6);
  static const Color dayCard = Color(0xFFE4EAF2);

  // Night (Dark) — 19:00 → 06:00
  static const Color nightBg = Color(0xFF1A1D2E);
  static const Color nightDarkShadow = Color(0xFF11131F);
  static const Color nightLightShadow = Color(0xFF252840);
  static const Color nightText = Color(0xFFE2E8F0);
  static const Color nightTextSub = Color(0xFF94A3B8);
  static const Color nightAccent = Color(0xFFAB82F0);
  static const Color nightAccentSoft = Color(0xFF2A1F45);
  static const Color nightCard = Color(0xFF1E2136);
}

// ─── Shadow Presets ──────────────────────────────────────────────────────────

class NeuShadows {
  static List<BoxShadow> raised(bool isDark, {double intensity = 1.0}) {
    final dark = isDark ? FolioColors.nightDarkShadow : FolioColors.dayDarkShadow;
    final light = isDark ? FolioColors.nightLightShadow : FolioColors.dayLightShadow;
    final blur = 12.0 * intensity;
    final dist = 6.0 * intensity;
    return [
      BoxShadow(color: dark, offset: Offset(dist, dist), blurRadius: blur),
      BoxShadow(color: light, offset: Offset(-dist, -dist), blurRadius: blur),
    ];
  }

  static List<BoxShadow> subtle(bool isDark) => raised(isDark, intensity: 0.5);

  static List<BoxShadow> pressed(bool isDark) {
    final dark = isDark ? FolioColors.nightDarkShadow : FolioColors.dayDarkShadow;
    final light = isDark ? FolioColors.nightLightShadow : FolioColors.dayLightShadow;
    return [
      BoxShadow(color: dark, offset: const Offset(3, 3), blurRadius: 6, spreadRadius: 1),
      BoxShadow(color: light, offset: const Offset(-3, -3), blurRadius: 6, spreadRadius: 1),
    ];
  }

  // Concave inset for active/selected states
  static List<BoxShadow> inset(bool isDark) {
    final dark = isDark ? FolioColors.nightDarkShadow : FolioColors.dayDarkShadow;
    final light = isDark ? FolioColors.nightLightShadow : FolioColors.dayLightShadow;
    return [
      BoxShadow(color: dark, offset: const Offset(4, 4), blurRadius: 8, spreadRadius: 0),
      BoxShadow(color: light, offset: const Offset(-4, -4), blurRadius: 8, spreadRadius: 0),
    ];
  }
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

  Color get bg => isDark ? FolioColors.nightBg : FolioColors.dayBg;
  Color get cardBg => isDark ? FolioColors.nightCard : FolioColors.dayCard;
  Color get text => isDark ? FolioColors.nightText : FolioColors.dayText;
  Color get textSub => isDark ? FolioColors.nightTextSub : FolioColors.dayTextSub;
  Color get accent => isDark ? FolioColors.nightAccent : FolioColors.dayAccent;
  Color get accentSoft => isDark ? FolioColors.nightAccentSoft : FolioColors.dayAccentSoft;
  Color get darkShadow => isDark ? FolioColors.nightDarkShadow : FolioColors.dayDarkShadow;
  Color get lightShadow => isDark ? FolioColors.nightLightShadow : FolioColors.dayLightShadow;

  // ─── Shadow shortcuts ─────────────────────────────────────────────────────

  List<BoxShadow> get raisedShadow => NeuShadows.raised(isDark);
  List<BoxShadow> get subtleShadow => NeuShadows.subtle(isDark);
  List<BoxShadow> get pressedShadow => NeuShadows.pressed(isDark);
  List<BoxShadow> get insetShadow => NeuShadows.inset(isDark);

  // ─── MaterialThemeData ────────────────────────────────────────────────────

  ThemeData get themeData => isDark ? _nightTheme() : _dayTheme();

  ThemeData _dayTheme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: FolioColors.dayBg,
      colorScheme: ColorScheme.light(
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
        backgroundColor: FolioColors.dayBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FolioColors.dayText,
        contentTextStyle: GoogleFonts.nunito(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ThemeData _nightTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: FolioColors.nightBg,
      colorScheme: ColorScheme.dark(
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
        backgroundColor: FolioColors.nightBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FolioColors.nightCard,
        contentTextStyle: GoogleFonts.nunito(color: FolioColors.nightText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
