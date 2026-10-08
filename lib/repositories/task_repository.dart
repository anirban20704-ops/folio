import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/database_helper.dart';
import '../models/task_model.dart';
import '../services/notification_service.dart';

class TaskRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService.instance;

  static String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Fetches tasks, and:
  /// - lazily un-ticks any "everyday" task completed on a previous day
  /// - rolls an everyday task's reminder time onto today's date (its
  ///   `deadline` only ever carries a time-of-day for daily tasks, not a
  ///   real one-time date, so this keeps "today at 8am" actually meaning
  ///   today rather than whatever day it was first set)
  /// Both run lazily here - no background job needed, since a day only
  /// needs to "roll over" the next time the task list is actually opened.
  Future<List<TaskItem>> getTasks() async {
    final tasks = await _db.getAllTasks();
    final now = DateTime.now();
    final today = _dateKey(now);
    final result = <TaskItem>[];

    for (var t in tasks) {
      if (t.isDaily && t.deadline != null && _dateKey(t.deadline!) != today) {
        final rolled = DateTime(
            now.year, now.month, now.day, t.deadline!.hour, t.deadline!.minute);
        await _db.updateTask(t.copyWith(deadline: rolled));
        t = t.copyWith(deadline: rolled);
      }
      final staleCompletion = t.isDaily &&
          t.isDone &&
          (t.completedDate == null || _dateKey(t.completedDate!) != today);
      if (staleCompletion) {
        await _db.setTaskDone(t.id!, false);
        t = t.copyWith(isDone: false, clearCompletedDate: true);
      }
      result.add(t);
    }
    return result;
  }

  Future<Directory> _imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'task_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies picked images into the app's own folder so they survive
  /// gallery/cache clean-ups, then stores the task.
  /// A task has no deadline unless one is explicitly given - nothing is
  /// auto-filled here. [notifyEnabled] is only meaningful when [deadline]
  /// (or, for daily tasks, a reminder time) is actually set; the UI is
  /// responsible for keeping the toggle off otherwise.
  Future<int> addTask(
    String description,
    List<String> sourceImagePaths, {
    DateTime? deadline,
    bool isDaily = false,
    bool notifyEnabled = false,
    String details = '',
  }) async {
    final saved = <String>[];
    if (sourceImagePaths.isNotEmpty) {
      final dir = await _imagesDir();
      for (final src in sourceImagePaths) {
        final name =
            '${DateTime.now().microsecondsSinceEpoch}_${p.basename(src)}';
        final dest = await File(src).copy(p.join(dir.path, name));
        saved.add(dest.path);
      }
    }
    final effectiveNotify = deadline != null && notifyEnabled;
    final id = await _db.insertTask(TaskItem(
      description: description,
      imagePaths: saved,
      createdAt: DateTime.now(),
      deadline: deadline,
      isDaily: isDaily,
      notifyEnabled: effectiveNotify,
      details: details,
    ));
    await _notifications.scheduleForTask(
      id: id,
      title: description,
      at: deadline,
      enabled: effectiveNotify,
      daily: isDaily,
    );
    return id;
  }

  /// Edits an existing task's description/images/deadline/daily flag.
  /// [finalImagePaths] is the complete desired image list after editing:
  /// a mix of paths already inside the app's image folder (kept as-is)
  /// and freshly picked paths (copied in). Anything from [original] that's
  /// no longer in [finalImagePaths] is deleted from disk.
  Future<void> updateTask({
    required TaskItem original,
    required String description,
    required List<String> finalImagePaths,
    DateTime? deadline,
    required bool isDaily,
    required bool notifyEnabled,
    String details = '',
  }) async {
    final dir = await _imagesDir();
    final saved = <String>[];
    for (final path in finalImagePaths) {
      final alreadySaved = p.equals(p.dirname(path), dir.path);
      if (alreadySaved) {
        saved.add(path);
      } else {
        final name =
            '${DateTime.now().microsecondsSinceEpoch}_${p.basename(path)}';
        final dest = await File(path).copy(p.join(dir.path, name));
        saved.add(dest.path);
      }
    }
    final removed = original.imagePaths.where((path) => !saved.contains(path));
    await _deleteImages(removed.toList());

    final effectiveNotify = deadline != null && notifyEnabled;
    await _db.updateTask(original.copyWith(
      description: description,
      imagePaths: saved,
      deadline: deadline,
      clearDeadline: deadline == null,
      isDaily: isDaily,
      notifyEnabled: effectiveNotify,
      details: details,
    ));
    await _notifications.scheduleForTask(
      id: original.id!,
      title: description,
      at: deadline,
      enabled: effectiveNotify,
      daily: isDaily,
    );
  }

  Future<int> setDone(int id, bool done) async {
    final result = await _db.setTaskDone(id, done);
    await _resyncReminder(id);
    return result;
  }

  Future<int> setDeadline(int id, DateTime? deadline) async {
    final result = await _db.setTaskDeadline(id, deadline);
    await _resyncReminder(id);
    return result;
  }

  /// Re-reads a task and makes its OS reminder match: a finished one-off
  /// task stops reminding (and starts again if un-ticked while still in the
  /// future); daily tasks keep their repeating reminder either way.
  Future<void> _resyncReminder(int id) async {
    final matches = (await _db.getAllTasks()).where((t) => t.id == id);
    if (matches.isEmpty) return;
    final t = matches.first;
    final finishedOneOff = t.isDone && !t.isDaily;
    await _notifications.scheduleForTask(
      id: id,
      title: t.description,
      at: t.deadline,
      enabled: t.notifyEnabled && !finishedOneOff,
      daily: t.isDaily,
    );
  }

  Future<void> deleteTask(int id) async {
    final tasks = await _db.getAllTasks();
    final match = tasks.where((t) => t.id == id);
    if (match.isNotEmpty) await _deleteImages(match.first.imagePaths);
    await _db.deleteTask(id);
    await _notifications.cancelForTask(id);
  }

  Future<void> clearCompleted() async {
    final tasks = await _db.getAllTasks();
    for (final t in tasks.where((t) => t.isDone && !t.isDaily)) {
      await _deleteImages(t.imagePaths);
      await _notifications.cancelForTask(t.id!);
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
