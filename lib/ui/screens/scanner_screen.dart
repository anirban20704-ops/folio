import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/scanner/scanner_bloc.dart';
import '../../blocs/scanner/scanner_event.dart';
import '../../blocs/scanner/scanner_state.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/dashboard/dashboard_event.dart';
import '../../blocs/dashboard/dashboard_state.dart';
import '../../core/folio_theme.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/deadline_notify_field.dart';
import '../widgets/image_viewer.dart';
import '../../core/limits.dart';
import 'studio_screen.dart';
import 'dart:io';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isReorderMode = false;
  DateTime? _deadline;
  bool _notifyEnabled = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    return BlocConsumer<ScannerBloc, ScannerState>(
      listener: (context, state) {
        if (state is ScannerImagesPicked) {
          _nameController.text =
              clampName(state.suggestedName, kMaxDocNameLength);
        }
        if (state is ScannerSaved) {
          context.read<DashboardBloc>().add(LoadDashboard());
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document saved successfully ✓')),
          );
        }
        if (state is ScannerError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final hasPicked = state is ScannerImagesPicked;
        return Scaffold(
          backgroundColor: theme.bg,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (ctx, _) => [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                // ─── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      ClayIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                        size: 44,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _isReorderMode ? 'Reorder Pages' : 'New Scan',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            color: theme.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      if (hasPicked) ...[
                        ClayIconButton(
                          icon: _isReorderMode ? Icons.grid_view_rounded : Icons.reorder_rounded,
                          onTap: () => setState(() => _isReorderMode = !_isReorderMode),
                          active: _isReorderMode,
                          size: 44,
                        ),
                        const SizedBox(width: 10),
                        ClayButton(
                          filled: true,
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          onTap: () => _showFolderSelection(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.save_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text('Save', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ─── Name field + optional deadline (only when images picked) ──
                if (hasPicked) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: ClayTextField(
                      controller: _nameController,
                      label: 'Document Name',
                      prefixIcon: Icons.edit_note_rounded,
                      maxLength: kMaxDocNameLength,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: DeadlineNotifyField(
                      initialDeadline: _deadline,
                      initialNotifyEnabled: _notifyEnabled,
                      onChanged: (deadline, notify) => setState(() {
                        _deadline = deadline;
                        _notifyEnabled = notify;
                      }),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                    body: _buildBody(context, state, theme),
                  ),
                ),

                // ─── Bottom Action Buttons ────────────────────────────────
                if (state is ScannerInitial || state is ScannerImagesPicked)
                  _buildActionBar(context, theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ScannerState state, FolioThemeNotifier theme) {
    if (state is ScannerLoading) return const Center(child: CircularProgressIndicator());

    if (state is ScannerImagesPicked) {
      return _isReorderMode
          ? _ReorderList(images: state.images, theme: theme)
          : _ImageGrid(images: state.images, theme: theme);
    }

    // Empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClayBox(
            borderRadius: 28,
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                Icon(Icons.document_scanner_outlined, size: 64, color: theme.textSub.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(
                  'Ready to Scan',
                  style: GoogleFonts.nunito(color: theme.text, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use camera or gallery below',
                  style: GoogleFonts.nunito(color: theme.textSub, fontWeight: FontWeight.w600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, FolioThemeNotifier theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Row(
        children: [
          Expanded(
            child: ClayButton(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(vertical: 16),
              onTap: () => context.read<ScannerBloc>().add(PickImages()),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, color: theme.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Gallery', style: GoogleFonts.nunito(color: theme.text, fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ClayButton(
              filled: true,
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(vertical: 16),
              onTap: () => context.read<ScannerBloc>().add(TakePhoto()),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Camera', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFolderSelection(BuildContext context) {
    final theme = context.read<FolioThemeNotifier>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.textSub.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Save to Folder', style: GoogleFonts.nunito(color: theme.text, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              Expanded(
                child: BlocBuilder<DashboardBloc, DashboardState>(
                  builder: (context, state) {
                    if (state is! DashboardLoaded) return const Center(child: CircularProgressIndicator());
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: state.folders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final folder = state.folders[index];
                        return ClayButton(
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          onTap: () {
                            context.read<ScannerBloc>().add(SaveDocument(
                              name: _nameController.text,
                              folderId: folder.id!,
                              deadline: _deadline,
                              notifyEnabled: _notifyEnabled,
                            ));
                            Navigator.pop(ctx);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: theme.accentSoft, borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.folder_rounded, color: theme.accent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(folder.name, style: GoogleFonts.nunito(color: theme.text, fontWeight: FontWeight.w700, fontSize: 15)),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded, color: theme.textSub, size: 20),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Grid ─────────────────────────────────────────────────────────────────────
/// Big thumbnails. Tap = view full size (swipe between pages), pencil = edit,
/// X = remove, long-press then drag onto another page = reorder.
class _ImageGrid extends StatefulWidget {
  final List<File> images;
  final FolioThemeNotifier theme;
  const _ImageGrid({required this.images, required this.theme});

  @override
  State<_ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends State<_ImageGrid> {
  Timer? _scrollTimer;
  double _dragY = 0;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final c = PrimaryScrollController.maybeOf(context);
      if (c == null || !c.hasClients) return;
      final mq = MediaQuery.of(context);
      const edge = 110.0;
      double delta = 0;
      if (_dragY < mq.padding.top + edge) {
        delta = -14;
      } else if (_dragY > mq.size.height - edge) {
        delta = 14;
      }
      if (delta == 0) return;
      c.jumpTo((c.offset + delta)
          .clamp(c.position.minScrollExtent, c.position.maxScrollExtent)
          .toDouble());
    });
  }

  Widget _card(BuildContext context, int index) {
    final images = widget.images;
    return GestureDetector(
      onTap: () => showImageViewer(
        context,
        paths: images.map((f) => f.path).toList(),
        initialIndex: index,
        labels: List.generate(images.length, (i) => 'Page ${i + 1}'),
      ),
      child: ClayBox(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        depth: ClayDepth.md,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: 600),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _miniButton(Icons.edit_outlined, () async {
                    final edited = await Navigator.push<File>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StudioScreen(image: images[index])),
                    );
                    if (edited != null && context.mounted) {
                      context
                          .read<ScannerBloc>()
                          .add(UpdateImage(index, edited));
                    }
                  }),
                  const SizedBox(width: 6),
                  _miniButton(Icons.close, () =>
                      context.read<ScannerBloc>().add(RemoveImage(index))),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('Page ${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) => LayoutBuilder(
        key: ValueKey(images[index].path),
        builder: (context, box) {
          final card = _card(context, index);
          return DragTarget<int>(
            onWillAcceptWithDetails: (d) => d.data != index,
            onAcceptWithDetails: (d) => context
                .read<ScannerBloc>()
                .add(ReorderImages(d.data, index)),
            builder: (context, candidates, _) => AnimatedScale(
              scale: candidates.isNotEmpty ? 0.93 : 1,
              duration: const Duration(milliseconds: 120),
              child: LongPressDraggable<int>(
                data: index,
                delay: const Duration(milliseconds: 350),
                hapticFeedbackOnStart: true,
                onDragStarted: _startAutoScroll,
                onDragUpdate: (d) => _dragY = d.globalPosition.dy,
                onDragEnd: (_) => _scrollTimer?.cancel(),
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: box.maxWidth,
                    height: box.maxHeight,
                    child: Opacity(
                      opacity: 0.92,
                      child: Transform.scale(scale: 1.05, child: card),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.25, child: card),
                child: card,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Reorder List ─────────────────────────────────────────────────────────────
class _ReorderList extends StatelessWidget {
  final List<File> images;
  final FolioThemeNotifier theme;
  const _ReorderList({required this.images, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: images.length,
      onReorderItem: (o, n) =>
          context.read<ScannerBloc>().add(ReorderImages(o, n)),
      itemBuilder: (context, index) => Padding(
        key: ValueKey(images[index].path),
        padding: const EdgeInsets.only(bottom: 12),
        child: ClayBox(
          borderRadius: 18,
          padding: EdgeInsets.zero,
          depth: ClayDepth.sm,
          child: ListTile(
            onTap: () => showImageViewer(
              context,
              paths: images.map((f) => f.path).toList(),
              initialIndex: index,
              labels: List.generate(images.length, (i) => 'Page ${i + 1}'),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(images[index],
                  width: 52, height: 52, fit: BoxFit.cover, cacheWidth: 200),
            ),
            title: Text('Page ${index + 1}',
                style: GoogleFonts.nunito(
                    color: theme.text, fontWeight: FontWeight.w800)),
            trailing: Icon(Icons.drag_handle_rounded, color: theme.textSub),
          ),
        ),
      ),
    );
  }
}
