import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import '../../core/color_filters.dart';
import '../../core/folio_theme.dart';
import '../widgets/neu_widgets.dart';
import 'package:image_cropper/image_cropper.dart';

class StudioScreen extends StatefulWidget {
  final File image;
  const StudioScreen({super.key, required this.image});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final GlobalKey _renderKey = GlobalKey();
  late File _currentImage;
  List<double> _selectedFilter = FolioFilters.original;
  String _selectedFilterName = 'Original';

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );
  bool _isDrawing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.image;
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _cropImage() async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _currentImage.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop'),
      ],
    );
    if (croppedFile != null) {
      setState(() => _currentImage = File(croppedFile.path));
    }
  }

  Future<void> _saveAndReturn() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _renderKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(bytes);

      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  NeuIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                    size: 44,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Edit Studio',
                    style: GoogleFonts.nunito(
                      color: theme.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  _isSaving
                      ? SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent),
                      ),
                    ),
                  )
                      : NeuButton(
                    filled: true,
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    onTap: _saveAndReturn,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Done', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Image Preview ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: NeuBox(
                  pressed: true,
                  borderRadius: 24,
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RepaintBoundary(
                      key: _renderKey,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ColorFiltered(
                            colorFilter: ColorFilter.matrix(_selectedFilter),
                            child: Image.file(
                              _currentImage,
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                          ),
                          if (_isDrawing)
                            Signature(
                              controller: _signatureController,
                              height: double.infinity,
                              width: double.infinity,
                              backgroundColor: Colors.transparent,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Filter Bar ────────────────────────────────────────────────
            _buildFilterBar(theme),

            const SizedBox(height: 12),

            // ─── Toolbar ───────────────────────────────────────────────────
            _buildToolbar(theme),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(FolioThemeNotifier theme) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        itemCount: FolioFilters.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final name = FolioFilters.all.keys.elementAt(index);
          final filter = FolioFilters.all.values.elementAt(index);
          final isSelected = _selectedFilterName == name;

          return GestureDetector(
            onTap: () => setState(() {
              _selectedFilter = filter;
              _selectedFilterName = name;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected ? theme.pressedShadow : theme.subtleShadow,
                border: isSelected
                    ? Border.all(color: theme.accent, width: 2)
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(filter),
                          child: Image.file(_currentImage, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: GoogleFonts.nunito(
                        color: isSelected ? theme.accent : theme.textSub,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar(FolioThemeNotifier theme) {
    final tools = [
      _ToolItem(icon: _isDrawing ? Icons.gesture : Icons.gesture_outlined, label: 'Sign', active: _isDrawing, onTap: () => setState(() => _isDrawing = !_isDrawing)),
      _ToolItem(icon: Icons.undo_rounded, label: 'Undo', onTap: () => _signatureController.undo()),
      _ToolItem(icon: Icons.clear_rounded, label: 'Clear', onTap: () => _signatureController.clear()),
      _ToolItem(icon: Icons.crop_rounded, label: 'Crop', onTap: _cropImage),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: NeuBox(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: tools.map((t) => _buildToolItem(t, theme)).toList(),
        ),
      ),
    );
  }

  Widget _buildToolItem(_ToolItem item, FolioThemeNotifier theme) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.active ? theme.accentSoft : theme.bg,
              shape: BoxShape.circle,
              boxShadow: item.active ? theme.pressedShadow : theme.subtleShadow,
            ),
            child: Icon(
              item.icon,
              color: item.active ? theme.accent : theme.textSub,
              size: 20,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.label,
            style: GoogleFonts.nunito(
              color: item.active ? theme.accent : theme.textSub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  _ToolItem({required this.icon, required this.label, required this.onTap, this.active = false});
}
