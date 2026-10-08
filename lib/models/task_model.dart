import 'dart:convert';
import 'package:equatable/equatable.dart';

class TaskItem extends Equatable {
  final int? id;
  final String description;
  final List<String> imagePaths;
  final bool isDone;
  final DateTime createdAt;
  final DateTime? deadline;
  final bool isDaily;
  final DateTime? completedDate;
  final bool notifyEnabled;

  /// Longer free-text description. Hidden on the card, shown when the
  /// task is tapped. [description] is the visible title.
  final String details;

  const TaskItem({
    this.id,
    required this.description,
    this.imagePaths = const [],
    this.isDone = false,
    required this.createdAt,
    this.deadline,
    this.isDaily = false,
    this.completedDate,
    this.notifyEnabled = false,
    this.details = '',
  });

  TaskItem copyWith({
    int? id,
    String? description,
    List<String>? imagePaths,
    bool? isDone,
    DateTime? createdAt,
    DateTime? deadline,
    bool clearDeadline = false,
    bool? isDaily,
    DateTime? completedDate,
    bool clearCompletedDate = false,
    bool? notifyEnabled,
    String? details,
  }) {
    return TaskItem(
      id: id ?? this.id,
      description: description ?? this.description,
      imagePaths: imagePaths ?? this.imagePaths,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      isDaily: isDaily ?? this.isDaily,
      completedDate:
          clearCompletedDate ? null : (completedDate ?? this.completedDate),
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      details: details ?? this.details,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'imagePaths': jsonEncode(imagePaths),
        'isDone': isDone ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
        'isDaily': isDaily ? 1 : 0,
        'completedDate': completedDate?.toIso8601String(),
        'notifyEnabled': notifyEnabled ? 1 : 0,
        'details': details,
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
      deadline: map['deadline'] == null
          ? null
          : DateTime.parse(map['deadline'] as String),
      isDaily: (map['isDaily'] as int? ?? 0) == 1,
      completedDate: map['completedDate'] == null
          ? null
          : DateTime.parse(map['completedDate'] as String),
      notifyEnabled: (map['notifyEnabled'] as int? ?? 0) == 1,
      details: (map['details'] as String?) ?? '',
    );
  }

  bool get isOverdue =>
      !isDone && deadline != null && deadline!.isBefore(DateTime.now());

  @override
  List<Object?> get props => [
        id,
        description,
        imagePaths,
        isDone,
        createdAt,
        deadline,
        isDaily,
        completedDate,
        notifyEnabled,
        details,
      ];
}
