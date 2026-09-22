import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/folder_model.dart';
import '../../models/document_model.dart';
import '../../repositories/document_repository.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/dashboard/dashboard_event.dart';
import '../../core/folio_theme.dart';
import '../widgets/document_list_tile.dart';
import '../widgets/neu_widgets.dart';
import 'document_detail_screen.dart';

class DocumentsByFolderScreen extends StatefulWidget {
  final Folder folder;

  const DocumentsByFolderScreen({super.key, required this.folder});

  @override
  State<DocumentsByFolderScreen> createState() => _DocumentsByFolderScreenState();
}

class _DocumentsByFolderScreenState extends State<DocumentsByFolderScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    final repository = context.read<DocumentRepository>();

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Custom Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  NeuIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                    size: 44,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Folder',
                          style: GoogleFonts.nunito(
                            color: theme.textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.folder.name,
                          style: GoogleFonts.nunito(
                            color: theme.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.folder_rounded, color: theme.accent, size: 24),
                  ),
                ],
              ),
            ),

            // ─── Document List ──────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<Document>>(
                future: repository.getDocumentsInFolder(widget.folder.id!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: NeuBox(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        borderRadius: 24,
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file_outlined, size: 52, color: theme.textSub.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'Folder is empty',
                              style: GoogleFonts.nunito(
                                color: theme.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scan a document and save it here',
                              style: GoogleFonts.nunito(
                                color: theme.textSub,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return Hero(
                        tag: 'doc_${doc.id}',
                        child: DocumentListTile(
                          doc: doc,
                          onTap: () => Navigator.push(
                            context,
                            _neuRoute(DocumentDetailScreen(
                              document: doc,
                              repository: repository,
                            )),
                          ),
                          onDelete: () {
                            context.read<DashboardBloc>().add(DeleteDocument(doc.id!));
                            setState(() {});
                          },
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
    );
  }
}

PageRoute _neuRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    transitionDuration: const Duration(milliseconds: 280),
  );
}
