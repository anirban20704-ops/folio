import 'package:equatable/equatable.dart';

class Document extends Equatable {
  final int? id;
  final int folderId;
  final String name;
  final DateTime createdAt;
  final DateTime? deadline;
  final bool notifyEnabled;

  const Document({
    this.id,
    required this.folderId,
    required this.name,
    required this.createdAt,
    this.deadline,
    this.notifyEnabled = false,
  });

  Document copyWith({
    int? id,
    int? folderId,
    String? name,
    DateTime? createdAt,
    DateTime? deadline,
    bool clearDeadline = false,
    bool? notifyEnabled,
  }) {
    return Document(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folderId': folderId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'notifyEnabled': notifyEnabled ? 1 : 0,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as int?,
      folderId: map['folderId'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      deadline: map['deadline'] == null
          ? null
          : DateTime.parse(map['deadline'] as String),
      notifyEnabled: (map['notifyEnabled'] as int? ?? 0) == 1,
    );
  }

  @override
  List<Object?> get props =>
      [id, folderId, name, createdAt, deadline, notifyEnabled];
}
