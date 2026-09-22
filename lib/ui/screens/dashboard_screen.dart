import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/dashboard/dashboard_event.dart';
import '../../blocs/dashboard/dashboard_state.dart';
import '../../blocs/scanner/scanner_bloc.dart';
import '../../blocs/scanner/scanner_event.dart';
import '../../repositories/document_repository.dart';
import '../widgets/document_list_tile.dart';
import '../widgets/folder_list_tile.dart';
import '../widgets/neu_widgets.dart';
import '../../core/folio_theme.dart';
import 'scanner_screen.dart';
import 'document_detail_screen.dart';
import 'documents_by_folder_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning ☀️';
    if (h < 17) return 'Good Afternoon 🌤';
    if (h < 21) return 'Good Evening 🌙';
    return 'Good Night 🌟';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    return Scaffold(
      backgroundColor: theme.bg,
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: GoogleFonts.nunito(
                                  color: theme.textSub,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Folio',
                                style: GoogleFonts.nunito(
                                  color: theme.text,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Theme toggle
                        _ThemeToggleButton(),
                        const SizedBox(width: 10),
                        // Scan FAB (top-right shortcut)
                        NeuButton(
                          filled: true,
                          borderRadius: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          onTap: () {
                            context.read<ScannerBloc>().add(ResetScanner());
                            Navigator.push(
                              context,
                              _neuRoute(const ScannerScreen()),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Scan',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ─── Body ─────────────────────────────────────────────────────
              if (state is DashboardInitial || state is DashboardLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state is DashboardError)
                SliverFillRemaining(child: _buildError(context, state))
              else if (state is DashboardLoaded) ...[
                  _buildSectionHeader(context, 'Folders', count: state.folders.length, onAdd: () => _showAddFolderDialog(context)),
                  _buildFolderList(context, state),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  _buildSectionHeader(context, 'Recent Scans', count: state.recentDocuments.length),
                  _buildRecentList(context, state),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, DashboardError state) {
    final theme = context.watch<FolioThemeNotifier>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 56, color: theme.textSub),
        const SizedBox(height: 16),
        Text(state.message, style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        NeuButton(
          onTap: () => context.read<DashboardBloc>().add(LoadDashboard()),
          child: Text('Retry', style: TextStyle(color: context.watch<FolioThemeNotifier>().accent, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  SliverToBoxAdapter _buildSectionHeader(
      BuildContext context,
      String title, {
        int? count,
        VoidCallback? onAdd,
      }) {
    final theme = context.watch<FolioThemeNotifier>();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 14),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.nunito(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: theme.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (onAdd != null)
              NeuIconButton(
                icon: Icons.create_new_folder_outlined,
                onTap: onAdd,
                size: 40,
                tooltip: 'New Folder',
              ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildFolderList(BuildContext context, DashboardLoaded state) {
    final theme = context.watch<FolioThemeNotifier>();
    if (state.folders.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: NeuBox(
            borderRadius: 16,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, color: theme.textSub, size: 28),
                const SizedBox(width: 12),
                Text(
                  'No folders yet. Create one above.',
                  style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          physics: const BouncingScrollPhysics(),
          itemCount: state.folders.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final folder = state.folders[index];
            return FolderListTile(
              folder: folder,
              onTap: () => Navigator.push(context, _neuRoute(DocumentsByFolderScreen(folder: folder))),
              onDelete: () => context.read<DashboardBloc>().add(DeleteFolder(folder.id!)),
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildRecentList(BuildContext context, DashboardLoaded state) {
    final theme = context.watch<FolioThemeNotifier>();
    if (state.recentDocuments.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: NeuBox(
            borderRadius: 20,
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.document_scanner_outlined, size: 56, color: theme.textSub.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  'No scans yet',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Scan to get started',
                  style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: state.recentDocuments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final doc = state.recentDocuments[index];
          return Hero(
            tag: 'doc_${doc.id}',
            child: DocumentListTile(
              doc: doc,
              onTap: () => Navigator.push(
                context,
                _neuRoute(DocumentDetailScreen(
                  document: doc,
                  repository: context.read<DocumentRepository>(),
                )),
              ),
              onDelete: () => context.read<DashboardBloc>().add(DeleteDocument(doc.id!)),
            ),
          );
        },
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    final theme = context.read<FolioThemeNotifier>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'New Folder',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w900),
        ),
        content: NeuTextField(
          controller: controller,
          label: 'Folder Name',
          prefixIcon: Icons.folder_outlined,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w700)),
          ),
          NeuButton(
            filled: true,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            onTap: () {
              if (controller.text.isNotEmpty) {
                context.read<DashboardBloc>().add(AddFolder(controller.text));
                Navigator.pop(ctx);
              }
            },
            child: Text('Create', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ─── Theme Toggle ─────────────────────────────────────────────────────────────
class _ThemeToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return GestureDetector(
      onLongPress: () {
        // Long press = reset to auto
        theme.setAuto();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Theme set to Auto (time-based)')),
        );
      },
      child: NeuIconButton(
        icon: theme.isDark
            ? Icons.nightlight_round
            : Icons.wb_sunny_rounded,
        active: !theme.isAuto,
        tooltip: theme.isAuto ? 'Auto (long-press to reset)' : 'Manual override',
        onTap: () => theme.isDark ? theme.setDark(false) : theme.setDark(true),
        size: 44,
      ),
    );
  }
}

// ─── Page Route Helper ────────────────────────────────────────────────────────
PageRoute _neuRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}
