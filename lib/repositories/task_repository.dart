import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/database_helper.dart';
import '../models/task_model.dart';

class TaskRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<TaskItem>> getTasks() => _db.getAllTasks();

  /// Copies picked images into the app's own folder so they survive
  /// gallery/cache clean-ups, then stores the task.
  Future<int> addTask(String description, List<String> sourceImagePaths) async {
    final saved = <String>[];
    if (sourceImagePaths.isNotEmpty) {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'task_images'));
      if (!await dir.exists()) await dir.create(recursive: true);
      for (final src in sourceImagePaths) {
        final name =
            '${DateTime.now().microsecondsSinceEpoch}_${p.basename(src)}';
        final dest = await File(src).copy(p.join(dir.path, name));
        saved.add(dest.path);
      }
    }
    return _db.insertTask(TaskItem(
      description: description,
      imagePaths: saved,
      createdAt: DateTime.now(),
    ));
  }

  Future<int> setDone(int id, bool done) => _db.setTaskDone(id, done);

  Future<void> deleteTask(int id) async {
    final tasks = await _db.getAllTasks();
    final match = tasks.where((t) => t.id == id);
    if (match.isNotEmpty) await _deleteImages(match.first.imagePaths);
    await _db.deleteTask(id);
  }

  Future<void> clearCompleted() async {
    final tasks = await _db.getAllTasks();
    for (final t in tasks.where((t) => t.isDone)) {
      await _deleteImages(t.imagePaths);
    }
    await _db.deleteCompletedTasks();
  }

  Future<void> _deleteImages(List<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
