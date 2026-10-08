import 'package:equatable/equatable.dart';
import '../../models/task_model.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {}

class AddTask extends TaskEvent {
  final String description;
  final List<String> imagePaths;
  final DateTime? deadline;
  final bool isDaily;
  final bool notifyEnabled;
  final String details;
  const AddTask(this.description, this.imagePaths,
      {this.deadline,
      this.isDaily = false,
      this.notifyEnabled = false,
      this.details = ''});
  @override
  List<Object?> get props =>
      [description, imagePaths, deadline, isDaily, notifyEnabled, details];
}

class UpdateTask extends TaskEvent {
  final TaskItem original;
  final String description;
  final List<String> finalImagePaths;
  final DateTime? deadline;
  final bool isDaily;
  final bool notifyEnabled;
  final String details;
  const UpdateTask({
    required this.original,
    required this.description,
    required this.finalImagePaths,
    this.deadline,
    required this.isDaily,
    this.notifyEnabled = false,
    this.details = '',
  });
  @override
  List<Object?> get props => [
        original,
        description,
        finalImagePaths,
        deadline,
        isDaily,
        notifyEnabled,
        details,
      ];
}

class ToggleTask extends TaskEvent {
  final int id;
  final bool done;
  const ToggleTask(this.id, this.done);
  @override
  List<Object?> get props => [id, done];
}

class SetDeadline extends TaskEvent {
  final int id;
  final DateTime? deadline; // null = remove deadline
  const SetDeadline(this.id, this.deadline);
  @override
  List<Object?> get props => [id, deadline];
}

class DeleteTask extends TaskEvent {
  final int id;
  const DeleteTask(this.id);
  @override
  List<Object?> get props => [id];
}

class ClearCompleted extends TaskEvent {}
