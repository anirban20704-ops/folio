import 'package:equatable/equatable.dart';
import '../../models/task_model.dart';

abstract class TaskState extends Equatable {
  const TaskState();
  @override
  List<Object> get props => [];
}

class TaskInitial extends TaskState {}

class TaskLoaded extends TaskState {
  final List<TaskItem> tasks;
  const TaskLoaded(this.tasks);

  /// Everyday tasks always show here, regardless of today's done status.
  List<TaskItem> get daily => tasks.where((t) => t.isDaily).toList()
    ..sort(_byDeadline);

  List<TaskItem> get active =>
      tasks.where((t) => !t.isDaily && !t.isDone).toList()..sort(_byDeadline);

  List<TaskItem> get completed =>
      tasks.where((t) => !t.isDaily && t.isDone).toList()..sort(_byDeadline);

  static int _byDeadline(TaskItem a, TaskItem b) {
    if (a.deadline == null && b.deadline == null) return 0;
    if (a.deadline == null) return 1;
    if (b.deadline == null) return -1;
    return a.deadline!.compareTo(b.deadline!);
  }

  @override
  List<Object> get props => [tasks];
}

class TaskError extends TaskState {
  final String message;
  const TaskError(this.message);
  @override
  List<Object> get props => [message];
}
