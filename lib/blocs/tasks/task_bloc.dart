import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/task_repository.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository repository;

  TaskBloc({required this.repository}) : super(TaskInitial()) {
    on<LoadTasks>((e, emit) => _reload(emit));
    on<AddTask>((e, emit) async {
      await _run(emit, () => repository.addTask(e.description, e.imagePaths));
    });
    on<ToggleTask>((e, emit) async {
      await _run(emit, () => repository.setDone(e.id, e.done));
    });
    on<DeleteTask>((e, emit) async {
      await _run(emit, () => repository.deleteTask(e.id));
    });
    on<ClearCompleted>((e, emit) async {
      await _run(emit, () => repository.clearCompleted());
    });
  }

  Future<void> _run(Emitter<TaskState> emit, Future<void> Function() action) async {
    try {
      await action();
      await _reload(emit);
    } catch (err) {
      emit(TaskError(err.toString()));
    }
  }

  Future<void> _reload(Emitter<TaskState> emit) async {
    try {
      emit(TaskLoaded(await repository.getTasks()));
    } catch (err) {
      emit(TaskError(err.toString()));
    }
  }
}
