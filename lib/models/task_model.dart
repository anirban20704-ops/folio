import 'dart:convert';
import 'package:equatable/equatable.dart';

class TaskItem extends Equatable {
  final int? id;
  final String description;
  final List<String> imagePaths;
  final bool isDone;
  final DateTime createdAt;

  const TaskItem({
    this.id,
    required this.description,
    this.imagePaths = const [],
    this.isDone = false,
    required this.createdAt,
  });

  TaskItem copyWith({
    int? id,
    String? description,
    List<String>? imagePaths,
    bool? isDone,
    DateTime? createdAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      description: description ?? this.description,
      imagePaths: imagePaths ?? this.imagePaths,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'imagePaths': jsonEncode(imagePaths),
        'isDone': isDone ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    final raw = map['imagePaths'] as String?;
    return TaskItem(
      id: map['id'] as int?,
      description: map['description'] as String,
      imagePaths: raw == null || raw.isEmpty
          ? const []
          : List<String>.from(jsonDecode(raw) as List),
      isDone: (map['isDone'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, description, imagePaths, isDone, createdAt];
}
