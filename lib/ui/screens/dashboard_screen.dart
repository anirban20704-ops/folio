import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/dashboard/dashboard_event.dart';
import '../../blocs/dashboard/dashboard_state.dart';
import '../../blocs/scanner/scanner_bloc.dart';
import '../../blocs/scanner/scanner_event.dart';
import '../../blocs/tasks/task_bloc.dart';
import '../../blocs/tasks/task_state.dart';
import '../../repositories/document_repository.dart';
import '../widgets/document_list_tile.dart';
import '../widgets/folder_list_tile.dart';
import '../widgets/folder_actions.dart';
import '../widgets/clay_widgets.dart';
import '../../core/folio_theme.dart';
import '../../core/limits.dart';
import 'scanner_screen.dart';
import 'task_manager_screen.dart';
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
      bottomNavigationBar: const _TasksBar(),
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
                              const FolioWordmark(size: 36),
                            ],
                          ),
                        ),
                        // Theme toggle (same spot on every screen)
                        const ClayThemeToggle(),
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
        ClayButton(
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
              ClayIconButton(
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
          child: ClayBox(
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
        height: folderTileSize(context),
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
              onTap: () => Navigator.push(context, _clayRoute(DocumentsByFolderScreen(folder: folder))),
              onRename: () => promptRenameFolder(context, folder),
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
          child: ClayBox(
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
                _clayRoute(DocumentDetailScreen(
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

  Future<void> _showAddFolderDialog(BuildContext context) async {
    // Names already in use (case-insensitive) so a duplicate is caught
    // right here, in the dialog, instead of silently creating a twin.
    final state = context.read<DashboardBloc>().state;
    final existing = state is DashboardLoaded
        ? state.folders.map((f) => f.name.toLowerCase()).toSet()
        : <String>{};
    final name = await showClayTextPrompt(
      context,
      title: 'New Folder',
      label: 'Folder Name',
      icon: Icons.folder_outlined,
      confirmLabel: 'Create',
      maxLength: kMaxFolderNameLength,
      validator: (t) => existing.contains(t.toLowerCase())
          ? 'A folder named "$t" already exists'
          : null,
    );
    if (name == null || !context.mounted) return;
    context.read<DashboardBloc>().add(AddFolder(name));
  }
}

// ─── Tasks Bar (bottom entry to Task Manager) ─────────────────────────────────
class _TasksBar extends StatelessWidget {
  const _TasksBar();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    return Container(
      color: theme.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: BlocBuilder<TaskBloc, TaskState>(
            builder: (context, state) {
              final pending = state is TaskLoaded ? state.active.length : 0;
              return Row(
                children: [
                  Expanded(
                    child: ClayButton(
                      borderRadius: 22,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      onTap: () => Navigator.push(
                          context, _clayRoute(const TaskManagerScreen())),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.checklist_rounded, color: theme.accent),
                          const SizedBox(width: 8),
                          const TasksTitle(size: 20),
                          if (pending > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: theme.accentSoft,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('$pending',
                                  style: TextStyle(
                                      color: theme.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ),
                          ],
                        ],
                      )),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ClayIconButton(
                    icon: Icons.document_scanner_rounded,
                    filled: true,
                    size: 58,
                    tooltip: 'Scan',
                    onTap: () {
                      context.read<ScannerBloc>().add(ResetScanner());
                      Navigator.push(context, _clayRoute(const ScannerScreen()));
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Page Route Helper ────────────────────────────────────────────────────────
PageRoute _clayRoute(Widget page) {
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
