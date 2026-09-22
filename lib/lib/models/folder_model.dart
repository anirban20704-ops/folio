import 'package:equatable/equatable.dart';

class Folder extends Equatable {
  final int? id;
  final String name;
  final DateTime createdAt;

  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Folder copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt];
}