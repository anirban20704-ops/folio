import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../models/document_model.dart';
import '../../models/page_model.dart';
import '../../repositories/document_repository.dart';
import '../../services/pdf_service.dart';
import '../../services/scanner_service.dart';
import '../../core/folio_theme.dart';
import '../../core/limits.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/deadline_notify_field.dart';
import '../widgets/image_viewer.dart';
import 'studio_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/dashboard/dashboard_event.dart';


class DocumentDetailScreen extends StatefulWidget {
  final Document document;
  final DocumentRepository repository;

  const DocumentDetailScreen({
    super.key,
    required this.document,
    required this.repository,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final PdfService _pdfService = PdfService();
  bool _isReorderMode = false;
  bool _isExtracting = false;
  bool _isSharing = false;
  List<PageModel>? _pages;
  late Document _doc = widget.document; // last SAVED version
  final ScrollController _scroll = ScrollController();
  Timer? _dragScroll;
  double _dragY = 0;

  // Deadline / reminder edits are a draft until "Save changes" is pressed.
  DateTime? _draftDeadline;
  bool _draftNotify = false;
  int _fieldVersion = 0;

  bool get _dirty {
    final savedNotify = _doc.deadline != null && _doc.notifyEnabled;
    final draftNotify = _draftDeadline != null && _draftNotify;
    return _draftDeadline != _doc.deadline || draftNotify != savedNotify;
  }

  void _onDeadlineChanged(DateTime? deadline, bool notify) {
    setState(() {
      _draftDeadline = deadline;
      _draftNotify = notify;
    });
  }

  Future<void> _saveChanges() async {
    final deadline = _draftDeadline;
    final notify = deadline != null && _draftNotify;
    await widget.repository
        .updateDeadline(_doc, deadline: deadline, notifyEnabled: notify);
    final fresh = await widget.repository.getDocument(_doc.id!);
    if (!mounted) return;
    setState(() {
      _doc = fresh ?? _doc.copyWith(
          deadline: deadline, clearDeadline: deadline == null, notifyEnabled: notify);
      _draftDeadline = _doc.deadline;
      _draftNotify = _doc.notifyEnabled;
    });
    context.read<DashboardBloc>().add(LoadDashboard());
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Changes saved')));
  }

  void _discardChanges() {
    setState(() {
      _draftDeadline = _doc.deadline;
      _draftNotify = _doc.notifyEnabled;
      _fieldVersion++; // rebuild the field with the saved values
    });
  }

  /// Back button / swipe: offer to save if there are unsaved changes.
  Future<void> _handleBack() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final theme = ctx.read<FolioThemeNotifier>();
        return AlertDialog(
          backgroundColor: theme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Unsaved changes',
              style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
          content: Text('Save your deadline / reminder changes before leaving?',
              style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w600)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'stay'),
                child: Text('Keep editing', style: TextStyle(color: theme.textSub))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'discard'),
                child: const Text('Discard',
                    style: TextStyle(color: Colors.redAccent))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: Text('Save',
                    style: TextStyle(color: theme.accent, fontWeight: FontWeight.w800))),
          ],
        );
      },
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'save') await _saveChanges();
    if (mounted) Navigator.pop(context);
  }

  /// The list passed in by the previous screen can be out of date (it was
  /// loaded before any deadline was saved), so always re-read from the DB.
  Future<void> _refreshDoc() async {
    final fresh = await widget.repository.getDocument(widget.document.id!);
    if (!mounted || fresh == null || _dirty) return;
    setState(() {
      _doc = fresh;
      _draftDeadline = fresh.deadline;
      _draftNotify = fresh.notifyEnabled;
      _fieldVersion++;
    });
  }

  @override
  void dispose() {
    _dragScroll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _draftDeadline = _doc.deadline;
    _draftNotify = _doc.notifyEnabled;
    _loadPages();
    _refreshDoc();
  }

  // ─── Rename ───────────────────────────────────────────────────────────────
  Future<void> _renameDocument() async {
    final newName = await showClayTextPrompt(
      context,
      title: 'Rename document',
      label: 'Document name',
      icon: Icons.edit_rounded,
      initialText: clampName(_doc.name, kMaxDocNameLength),
      maxLength: kMaxDocNameLength,
    );
    if (!mounted) return;
    if (newName == null || newName.isEmpty || newName == _doc.name) return;
    final updated = await widget.repository.renameDocument(_doc, newName);
    if (!mounted) return;
    setState(() => _doc = updated);
    context.read<DashboardBloc>().add(LoadDashboard());
    HapticFeedback.lightImpact();
  }

  Future<void> _loadPages() async {
    final pages = await widget.repository.getPages(widget.document.id!);
    if (mounted) setState(() => _pages = pages);
  }

  // ─── OCR Text Extraction ──────────────────────────────────────────────────
  Future<void> _extractText() async {
    if (_pages == null || _pages!.isEmpty) return;
    setState(() => _isExtracting = true);

    try {
      final scannerService = context.read<ScannerService>();
      final buffer = StringBuffer();
      for (int i = 0; i < _pages!.length; i++) {
        final text = await scannerService.extractTextFromImage(File(_pages![i].imagePath));
        if (text.isNotEmpty) {
          buffer.writeln('─── Page ${i + 1} ───');
          buffer.writeln(text);
          buffer.writeln();
        }
      }
      final result = buffer.toString().trim();
      if (mounted) {
        setState(() => _isExtracting = false);
        _showExtractedText(result.isEmpty ? 'No text found in this document.' : result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR error: $e')),
        );
      }
    }
  }

  void _showExtractedText(String text) {
    final theme = context.read<FolioThemeNotifier>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: theme.darkShadow.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSub.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.text_fields_rounded, color: theme.accent, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Extracted Text',
                      style: GoogleFonts.nunito(
                        color: theme.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    // Copy button
                    ClayButton(
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: theme.accent, size: 16),
                          const SizedBox(width: 6),
                          Text('Copy', style: GoogleFonts.nunito(color: theme.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Text content
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: ClayBox(
                    pressed: true,
                    borderRadius: 16,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      text,
                      style: GoogleFonts.nunito(
                        color: theme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportAndShare() async {
    if (_isSharing || _pages == null || _pages!.isEmpty) return;
    setState(() => _isSharing = true);
    try {
      final images = _pages!.map((p) => File(p.imagePath)).toList();
      final pdfFile = await _pdfService.generatePdf(images, _doc.name);
      if (!mounted) return;
      await Share.shareXFiles([XFile(pdfFile.path)], text: 'Document from Folio');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _viewImages(int index) {
    final pages = _pages;
    if (pages == null || pages.isEmpty) return;
    showImageViewer(
      context,
      paths: pages.map((p) => p.imagePath).toList(),
      initialIndex: index,
      labels: List.generate(pages.length, (i) => 'Page ${i + 1}'),
    );
  }

  Future<void> _movePage(int from, int to) async {
    if (from == to || _pages == null) return;
    setState(() {
      final item = _pages!.removeAt(from);
      _pages!.insert(to, item);
    });
    for (int i = 0; i < _pages!.length; i++) {
      await widget.repository.updatePage(_pages![i].copyWith(pageOrder: i));
    }
  }

  // Scrolls the screen while a page is dragged near the top/bottom edge.
  void _startDragScroll() {
    _dragScroll?.cancel();
    _dragScroll = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!_scroll.hasClients) return;
      final mq = MediaQuery.of(context);
      const edge = 110.0;
      double delta = 0;
      if (_dragY < mq.padding.top + edge) {
        delta = -14;
      } else if (_dragY > mq.size.height - edge) {
        delta = 14;
      }
      if (delta == 0) return;
      final target = (_scroll.offset + delta)
          .clamp(0.0, _scroll.position.maxScrollExtent)
          .toDouble();
      _scroll.jumpTo(target);
    });
  }

  void _stopDragScroll() {
    _dragScroll?.cancel();
    _dragScroll = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: theme.bg,
        body: SafeArea(
          // Everything scrolls together, so in landscape or with a big font
          // the header can never squeeze the pages out of view.
          child: CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildTop(theme)),
              _buildPagesSliver(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTop(FolioThemeNotifier theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              ClayIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _handleBack,
                size: 44,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _renameDocument,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    _doc.name,
                    style: GoogleFonts.nunito(
                      color: theme.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ClayIconButton(
                icon: Icons.edit_rounded,
                onTap: _renameDocument,
                size: 44,
                tooltip: 'Rename',
              ),
            ],
          ),
        ),

        // ─── Deadline / reminder (optional) + Save changes ───────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: DeadlineNotifyField(
            key: ValueKey('deadline_$_fieldVersion'),
            initialDeadline: _draftDeadline,
            initialNotifyEnabled: _draftNotify,
            onChanged: _onDeadlineChanged,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _dirty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClayButton(
                          filled: true,
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onTap: _saveChanges,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text('Save changes',
                                  style: GoogleFonts.nunito(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: _discardChanges,
                        child: Text('Discard',
                            style: TextStyle(
                                color: theme.textSub,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),

        // ─── Action Row ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ClayIconButton(
                      icon: _isReorderMode
                          ? Icons.grid_view_rounded
                          : Icons.reorder_rounded,
                      onTap: () =>
                          setState(() => _isReorderMode = !_isReorderMode),
                      active: _isReorderMode,
                      tooltip: _isReorderMode ? 'Grid View' : 'List View',
                      size: 44,
                    ),
                    ClayIconButton(
                      icon: Icons.share_outlined,
                      onTap: _exportAndShare,
                      size: 44,
                      tooltip: 'Share PDF',
                    ),
                    ClayIconButton(
                      icon: Icons.picture_as_pdf_outlined,
                      onTap: () async {
                        if (_pages == null) return;
                        final images =
                            _pages!.map((p) => File(p.imagePath)).toList();
                        final pdfFile =
                            await _pdfService.generatePdf(images, _doc.name);
                        await OpenFilex.open(pdfFile.path);
                      },
                      size: 44,
                      tooltip: 'Open PDF',
                    ),
                    _isExtracting
                        ? SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: theme.accent),
                              ),
                            ),
                          )
                        : ClayIconButton(
                            icon: Icons.text_fields_rounded,
                            onTap: _extractText,
                            size: 44,
                            tooltip: 'Extract Text (OCR)',
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ClayButton(
                filled: true,
                borderRadius: 14,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onTap: () => _addPages(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_a_photo_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Add',
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPagesSliver(FolioThemeNotifier theme) {
    if (_pages == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_pages!.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('No pages found.',
                style: TextStyle(
                    color: theme.textSub, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }
    return _isReorderMode ? _buildReorderableList(theme) : _buildGrid(theme);
  }

  /// One big page card. Tap = view full size, pencil = edit, bin = delete.
  Widget _pageCard(FolioThemeNotifier theme, int index, PageModel page) {
    return GestureDetector(
      onTap: () => _viewImages(index),
      child: ClayBox(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        depth: ClayDepth.md,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(page.imagePath),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 600,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _PageActionButton(
                    icon: Icons.edit_outlined,
                    onTap: () async {
                      final editedImage = await Navigator.push<File>(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                StudioScreen(image: File(page.imagePath))),
                      );
                      if (editedImage != null) {
                        await widget.repository.updatePage(
                            page.copyWith(imagePath: editedImage.path));
                        _loadPages();
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _PageActionButton(
                    icon: Icons.delete_outline_rounded,
                    danger: true,
                    onTap: () async {
                      await widget.repository.deletePage(page.id!);
                      _loadPages();
                    },
                  ),
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
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Page ${index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(FolioThemeNotifier theme) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: SliverGrid(
        // Adapts to the width: 2 columns on a phone, more in landscape.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          childCount: _pages!.length,
          (context, index) {
            final page = _pages![index];
            return LayoutBuilder(
              key: ValueKey('cell_${page.id}'),
              builder: (context, box) {
                final card = _pageCard(theme, index, page);
                // Long-press a page, then drag it onto another to reorder.
                return DragTarget<int>(
                  onWillAcceptWithDetails: (d) => d.data != index,
                  onAcceptWithDetails: (d) => _movePage(d.data, index),
                  builder: (context, candidates, _) => AnimatedScale(
                    scale: candidates.isNotEmpty ? 0.93 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: LongPressDraggable<int>(
                      data: index,
                      delay: const Duration(milliseconds: 350),
                      hapticFeedbackOnStart: true,
                      onDragStarted: _startDragScroll,
                      onDragUpdate: (d) => _dragY = d.globalPosition.dy,
                      onDragEnd: (_) => _stopDragScroll(),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildReorderableList(FolioThemeNotifier theme) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: SliverReorderableList(
        itemCount: _pages!.length,
        onReorderItem: (oldIndex, newIndex) => _movePage(oldIndex, newIndex),
        itemBuilder: (context, index) {
          final page = _pages![index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey('row_${page.id}'),
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClayBox(
                borderRadius: 18,
                padding: EdgeInsets.zero,
                depth: ClayDepth.sm,
                child: ListTile(
                  onTap: () => _viewImages(index),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(page.imagePath),
                        width: 52, height: 52, fit: BoxFit.cover, cacheWidth: 200),
                  ),
                  title: Text(
                    'Page ${index + 1}',
                    style: GoogleFonts.nunito(
                        color: theme.text, fontWeight: FontWeight.w800),
                  ),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_handle_rounded, color: theme.textSub),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addPages(BuildContext context) async {
    final scannerService = context.read<ScannerService>();
    final theme = context.read<FolioThemeNotifier>();

    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: theme.textSub.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Add More Pages', style: GoogleFonts.nunito(color: theme.text, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: ClayButton(
                        borderRadius: 18,
                        padding: const EdgeInsets.all(20),
                        onTap: () => Navigator.pop(ctx, 'camera'),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt_outlined, color: theme.accent, size: 28),
                            const SizedBox(height: 8),
                            Text('Camera', style: GoogleFonts.nunito(color: theme.text, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClayButton(
                        borderRadius: 18,
                        padding: const EdgeInsets.all(20),
                        onTap: () => Navigator.pop(ctx, 'gallery'),
                        child: Column(
                          children: [
                            Icon(Icons.photo_library_outlined, color: theme.accent, size: 28),
                            const SizedBox(height: 8),
                            Text('Gallery', style: GoogleFonts.nunito(color: theme.text, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    List<File> newImages = [];
    if (source == 'camera') {
      final img = await scannerService.pickImageFromCamera();
      if (img != null) newImages.add(img);
    } else {
      newImages = await scannerService.pickImages();
    }

    if (newImages.isEmpty) return;
    if (!context.mounted) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final startOrder = _pages?.length ?? 0;
      for (int i = 0; i < newImages.length; i++) {
        final permanentFile = await scannerService.saveImageToPermanentStorage(newImages[i]);
        await widget.repository.addPage(PageModel(
          documentId: widget.document.id!,
          imagePath: permanentFile.path,
          pageOrder: startOrder + i,
        ));
      }
      if (context.mounted) Navigator.pop(context);
      _loadPages();
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─── Helper Widget ────────────────────────────────────────────────────────────
class _PageActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _PageActionButton({required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: danger ? Colors.redAccent : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 16, color: danger ? Colors.white : Colors.black87),
      ),
    );
  }
}
