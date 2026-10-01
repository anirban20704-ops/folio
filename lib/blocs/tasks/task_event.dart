import 'package:equatable/equatable.dart';

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
  const AddTask(this.description, this.imagePaths, {this.deadline});
  @override
  List<Object?> get props => [description, imagePaths, deadline];
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
