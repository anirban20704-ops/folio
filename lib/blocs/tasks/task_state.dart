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

  List<TaskItem> get active => tasks.where((t) => !t.isDone).toList();
  List<TaskItem> get completed => tasks.where((t) => t.isDone).toList();

  @override
  List<Object> get props => [tasks];
}

class TaskError extends TaskState {
  final String message;
  const TaskError(this.message);
  @override
  List<Object> get props => [message];
}
