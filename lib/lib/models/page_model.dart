import 'package:equatable/equatable.dart';

class PageModel extends Equatable {
  final int? id;
  final int documentId;
  final String imagePath;
  final int pageOrder;
  final String? metadata;

  const PageModel({
    this.id,
    required this.documentId,
    required this.imagePath,
    required this.pageOrder,
    this.metadata,
  });

  PageModel copyWith({
    int? id,
    int? documentId,
    String? imagePath,
    int? pageOrder,
    String? metadata,
  }) {
    return PageModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      imagePath: imagePath ?? this.imagePath,
      pageOrder: pageOrder ?? this.pageOrder,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'imagePath': imagePath,
      'pageOrder': pageOrder,
      'metadata': metadata,
    };
  }

  factory PageModel.fromMap(Map<String, dynamic> map) {
    return PageModel(
      id: map['id'] as int?,
      documentId: map['documentId'] as int,
      imagePath: map['imagePath'] as String,
      pageOrder: map['pageOrder'] as int,
      metadata: map['metadata'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, documentId, imagePath, pageOrder, metadata];
}