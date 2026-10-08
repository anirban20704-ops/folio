import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/dashboard/dashboard_event.dart';
import '../../models/folder_model.dart';
import '../../repositories/document_repository.dart';
import 'clay_widgets.dart';

/// Asks for a new name and renames [folder].
///
/// Returns the updated folder, or null if the user cancelled or the rename
/// failed (a message is shown in that case). Used by both the dashboard tile
/// and the folder screen so renaming behaves the same everywhere.
///
/// Everything needed from [context] is read BEFORE the first await, so no
/// BuildContext is touched after the dialog closes.
Future<Folder?> promptRenameFolder(BuildContext context, Folder folder) async {
  final repo = context.read<DocumentRepository>();
  final bloc = context.read<DashboardBloc>();
  final messenger = ScaffoldMessenger.of(context);

  final others = (await repo.getFolders())
      .where((f) => f.id != folder.id)
      .map((f) => f.name.toLowerCase())
      .toSet();
  if (!context.mounted) return null;

  final name = await showClayTextPrompt(
    context,
    title: 'Rename folder',
    label: 'Folder name',
    icon: Icons.folder_outlined,
    initialText: folder.name,
    validator: (text) => others.contains(text.toLowerCase())
        ? 'A folder named "$text" already exists'
        : null,
  );
  if (name == null || name == folder.name) return null;

  final result = await repo.renameFolder(folder.id!, name);
  if (result == RenameFolderResult.renamed) {
    bloc.add(LoadDashboard());
    return folder.copyWith(name: name);
  }
  messenger.showSnackBar(SnackBar(
    content: Text(result == RenameFolderResult.nameTaken
        ? 'A folder named "$name" already exists'
        : "Couldn't rename the folder"),
  ));
  return null;
}
