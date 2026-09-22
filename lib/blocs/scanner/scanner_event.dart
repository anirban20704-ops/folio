import 'package:equatable/equatable.dart';
import 'dart:io';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

class PickImages extends ScannerEvent {}

class TakePhoto extends ScannerEvent {}

class ResetScanner extends ScannerEvent {}

class RemoveImage extends ScannerEvent {
  final int index;
  const RemoveImage(this.index);

  @override
  List<Object?> get props => [index];
}

class ReorderImages extends ScannerEvent {
  final int oldIndex;
  final int newIndex;
  const ReorderImages(this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

class UpdateImage extends ScannerEvent {
  final int index;
  final File newImage;
  const UpdateImage(this.index, this.newImage);

  @override
  List<Object?> get props => [index, newImage];
}

class SaveDocument extends ScannerEvent {
  final String name;
  final int folderId;
  const SaveDocument({required this.name, required this.folderId});

  @override
  List<Object?> get props => [name, folderId];
}