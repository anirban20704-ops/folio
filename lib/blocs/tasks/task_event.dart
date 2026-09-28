import 'package:equatable/equatable.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object> get props => [];
}

class LoadTasks extends TaskEvent {}

class AddTask extends TaskEvent {
  final String description;
  final List<String> imagePaths;
  const AddTask(this.description, this.imagePaths);
  @override
  List<Object> get props => [description, imagePaths];
}

class ToggleTask extends TaskEvent {
  final int id;
  final bool done;
  const ToggleTask(this.id, this.done);
  @override
  List<Object> get props => [id, done];
}

class DeleteTask extends TaskEvent {
  final int id;
  const DeleteTask(this.id);
  @override
  List<Object> get props => [id];
}

class ClearCompleted extends TaskEvent {}
