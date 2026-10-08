import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/folder_model.dart';
import '../../core/folio_theme.dart';
import 'clay_widgets.dart';


class FolderListTile extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const FolderListTile({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FolioThemeNotifier>();
    // Guard default folder from deletion
    final canDelete = folder.id != 1;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context, theme, canDelete),
      child: ClayBox(width: 120,
        borderRadius: 20, padding: EdgeInsets.zero, depth: ClayDepth.md, child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  color: theme.accent,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                folder.name,
                style: GoogleFonts.nunito(
                  color: theme.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                folder.createdAt.toString().split(' ')[0],
                style: GoogleFonts.nunito(
                  color: theme.textSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(
      BuildContext context, FolioThemeNotifier theme, bool canDelete) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: theme.textSub.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                      color: theme.textSub,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              ListTile(
                leading: Icon(Icons.edit_rounded, color: theme.accent),
                title: Text('Rename folder',
                    style: TextStyle(
                        color: theme.text, fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(ctx, 'rename'),
              ),
              if (canDelete)
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('Delete folder',
                      style: TextStyle(
                          color: Colors.redAccent, fontWeight: FontWeight.w800)),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'rename') {
      onRename();
    } else if (action == 'delete') {
      _confirmDelete(context, theme);
    }
  }

  void _confirmDelete(BuildContext context, FolioThemeNotifier theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Folder?', style: TextStyle(color: theme.text, fontWeight: FontWeight.w900)),
        content: Text(
          'This will delete "${folder.name}" and all its contents.',
          style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.textSub, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
