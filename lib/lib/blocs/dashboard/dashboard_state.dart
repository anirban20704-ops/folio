import 'package:equatable/equatable.dart';
import '../../models/folder_model.dart';
import '../../models/document_model.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<Folder> folders;
  final List<Document> recentDocuments;

  const DashboardLoaded({
    required this.folders,
    required this.recentDocuments,
  });

  @override
  List<Object> get props => [folders, recentDocuments];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}