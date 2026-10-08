import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/dashboard/dashboard_state.dart';
import '../../core/folio_theme.dart';
import '../widgets/clay_widgets.dart';
import 'dashboard_screen.dart';

/// Animated loading screen shown when the app starts.
///
/// Three clay pages pop out and fan into a stack, a scanner beam sweeps the
/// front page, the "Folio" wordmark bounces in letter by letter, and a clay
/// progress bar fills while the dashboard data loads. It moves on to the
/// dashboard once the intro has played AND the data is ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _introMs = 2800;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  );

  // Endless loop that drives the scan beam and the floating blobs.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final bloc = context.read<DashboardBloc>();
    final introDone = _intro.forward().orCancel.catchError((_) {});
    final dataReady = _waitForData(bloc);
    await Future.wait([introDone, dataReady]);
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _waitForData(DashboardBloc bloc) async {
    bool ready(DashboardState s) => s is DashboardLoaded || s is DashboardError;
    if (ready(bloc.state)) return;
    try {
      await bloc.stream
          .firstWhere(ready)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Don't trap the user on the splash if loading is slow.
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  // 0→1 progress of the intro between [a] and [b], eased by [curve].
  double _seg(double a, double b, [Curve curve = Curves.linear]) {
    return curve.transform(_c01((_intro.value - a) / (b - a)));
  }

  static double _c01(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    return Scaffold(
      backgroundColor: theme.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, _) {
          return Stack(
            children: [
              ..._blobs(theme),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pageStack(theme),
                    const SizedBox(height: 44),
                    _wordmark(theme),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: _seg(0.62, 0.82),
                      child: Text(
                        'Your offline document studio',
                        style: GoogleFonts.nunito(
                          color: theme.textSub,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _progress(theme),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Floating clay blobs ──────────────────────────────────────────────────
  List<Widget> _blobs(FolioThemeNotifier theme) {
    final d = theme.isDark;
    Widget blob(double size, Alignment a, double phase, bool accent) {
      final bob = math.sin(_loop.value * 2 * math.pi + phase) * 10;
      final appear = _c01(_seg(0.05, 0.45, Curves.easeOutBack));
      return Align(
        alignment: a,
        child: Transform.translate(
          offset: Offset(0, bob),
          child: Opacity(
            opacity: appear,
            child: ClaySurface(
              width: size,
              height: size,
              circle: true,
              radius: size / 2,
              color: accent ? theme.accent : theme.cardBg,
              gradient: accent ? theme.accentGradient : null,
              border: accent ? null : theme.clayBorder,
              drop: accent
                  ? ClayShadows.accentDrop(d)
                  : ClayShadows.drop(d, ClayDepth.sm),
              inner: accent
                  ? ClayShadows.accentInner(d)
                  : ClayShadows.inner(d, ClayDepth.sm),
            ),
          ),
        ),
      );
    }

    return [
      blob(54, const Alignment(-0.78, -0.62), 0.0, true),
      blob(34, const Alignment(0.82, -0.40), 2.1, false),
      blob(26, const Alignment(-0.70, 0.55), 4.0, false),
      blob(44, const Alignment(0.74, 0.62), 1.0, true),
    ];
  }

  // ─── Three fanning clay pages + scanner beam ──────────────────────────────
  Widget _pageStack(FolioThemeNotifier theme) {
    const w = 118.0;
    const h = 150.0;

    Widget page({
      required double angle,
      required double dx,
      required double start,
      required Widget child,
    }) {
      final e = _seg(start, start + 0.32, Curves.elasticOut);
      final fade = _c01(_seg(start, start + 0.12));
      return Opacity(
        opacity: fade,
        child: Transform.translate(
          offset: Offset(dx * e, (1 - e) * 46),
          child: Transform.rotate(
            angle: angle * e,
            child: Transform.scale(scale: 0.55 + 0.45 * e, child: child),
          ),
        ),
      );
    }

    Widget plain(Color tint) => ClayBox(
          width: w,
          height: h,
          borderRadius: 26,
          depth: ClayDepth.sm,
          overrideColor: tint,
          child: const SizedBox.shrink(),
        );

    // Front page: text lines + sweeping scan beam.
    final beamY = (_loop.value * (h + 24)) - 12;
    final front = ClayBox(
      width: w,
      height: h,
      borderRadius: 26,
      depth: ClayDepth.md,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: theme.accentGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.description_rounded,
                        color: Colors.white, size: 19),
                  ),
                  const SizedBox(height: 16),
                  _line(theme, 1.0),
                  const SizedBox(height: 9),
                  _line(theme, 0.78),
                  const SizedBox(height: 9),
                  _line(theme, 0.9),
                  const SizedBox(height: 9),
                  _line(theme, 0.52),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: beamY,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.accent.withValues(alpha: 0),
                    theme.accent,
                    theme.accent.withValues(alpha: 0),
                  ]),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: w + 90,
      height: h + 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          page(angle: -0.26, dx: -30, start: 0.00, child: plain(theme.accentSoft)),
          page(angle: 0.24, dx: 30, start: 0.10, child: plain(
              theme.isDark ? const Color(0xFF273449) : const Color(0xFFEFF3FB))),
          page(angle: 0.0, dx: 0, start: 0.20, child: front),
        ],
      ),
    );
  }

  Widget _line(FolioThemeNotifier theme, double factor) => FractionallySizedBox(
        widthFactor: factor,
        child: Container(
          height: 7,
          decoration: BoxDecoration(
            color: theme.textSub.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  // ─── Wordmark: letters bounce in one by one ───────────────────────────────
  Widget _wordmark(FolioThemeNotifier theme) {
    const word = 'Folio';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(word.length, (i) {
        final s = _seg(0.40 + 0.05 * i, 0.62 + 0.05 * i, Curves.easeOutBack);
        return Opacity(
          opacity: _c01(s),
          child: Transform.translate(
            offset: Offset(0, (1 - s) * 26),
            child: Text(
              word[i],
              style: FolioFonts.display(
                color: i == 3 ? theme.accent : theme.text,
                size: 56,
                letterSpacing: -1,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── Clay progress bar ────────────────────────────────────────────────────
  Widget _progress(FolioThemeNotifier theme) {
    final d = theme.isDark;
    final p = _seg(0.15, 1.0, Curves.easeInOutCubic);
    final label = p < 0.35
        ? 'Gathering your pages…'
        : p < 0.8
            ? 'Scanning your folio…'
            : 'Almost ready…';

    return Opacity(
      opacity: _seg(0.10, 0.30),
      child: Column(
        children: [
          ClaySurface(
            width: 190,
            height: 18,
            radius: 9,
            color: d ? theme.bg : const Color(0xFFF6F8FC),
            inner: ClayShadows.pressedInner(d, ClayDepth.sm),
            padding: const EdgeInsets.all(3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: math.max(p, 0.06),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: theme.accentGradient,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accent.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: theme.textSub,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
