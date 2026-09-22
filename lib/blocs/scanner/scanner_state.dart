import 'package:equatable/equatable.dart';
import 'dart:io';

abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerLoading extends ScannerState {}

class ScannerImagesPicked extends ScannerState {
  final List<File> images;
  final String suggestedName;

  const ScannerImagesPicked({
    required this.images,
    required this.suggestedName,
  });

  @override
  List<Object?> get props => [images, suggestedName];
}

class ScannerSaved extends ScannerState {}

class ScannerError extends ScannerState {
  final String message;
  const ScannerError(this.message);

  @override
  List<Object?> get props => [message];
}