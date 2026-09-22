import 'package:flutter_bloc/flutter_bloc.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';
import '../../services/scanner_service.dart';
import '../../repositories/document_repository.dart';
import '../../models/page_model.dart';
import 'dart:io';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final ScannerService scannerService;
  final DocumentRepository repository;

  ScannerBloc({
    required this.scannerService,
    required this.repository,
  }) : super(ScannerInitial()) {
    on<PickImages>(_onPickImages);
    on<TakePhoto>(_onTakePhoto);
    on<ResetScanner>(_onResetScanner);
    on<RemoveImage>(_onRemoveImage);
    on<ReorderImages>(_onReorderImages);
    on<UpdateImage>(_onUpdateImage);
    on<SaveDocument>(_onSaveDocument);
  }

  Future<void> _onPickImages(PickImages event, Emitter<ScannerState> emit) async {
    final List<File> currentImages = state is ScannerImagesPicked ? (state as ScannerImagesPicked).images : [];
    emit(ScannerLoading());
    try {
      final images = await scannerService.pickImages();
      if (images.isEmpty && currentImages.isEmpty) {
        emit(ScannerInitial());
        return;
      }

      final updatedImages = [...currentImages, ...images];

      String suggestedName = 'New Document';
      if (updatedImages.isNotEmpty) {
        suggestedName = await scannerService.getSmartName(updatedImages.first);
      }

      emit(ScannerImagesPicked(images: updatedImages, suggestedName: suggestedName));
    } catch (e) {
      emit(ScannerError(e.toString()));
    }
  }

  Future<void> _onTakePhoto(TakePhoto event, Emitter<ScannerState> emit) async {
    final List<File> currentImages = state is ScannerImagesPicked ? (state as ScannerImagesPicked).images : [];
    // Don't emit loading here to keep the current UI visible if we are adding pages
    try {
      final image = await scannerService.pickImageFromCamera();
      if (image == null) return;

      final updatedImages = [...currentImages, image];

      String suggestedName = 'New Document';
      if (updatedImages.isNotEmpty) {
        suggestedName = await scannerService.getSmartName(updatedImages.first);
      }

      emit(ScannerImagesPicked(images: updatedImages, suggestedName: suggestedName));
    } catch (e) {
      emit(ScannerError(e.toString()));
    }
  }

  void _onResetScanner(ResetScanner event, Emitter<ScannerState> emit) {
    emit(ScannerInitial());
  }

  void _onRemoveImage(RemoveImage event, Emitter<ScannerState> emit) {
    if (state is ScannerImagesPicked) {
      final currentState = state as ScannerImagesPicked;
      final updatedImages = List<File>.from(currentState.images)..removeAt(event.index);
      if (updatedImages.isEmpty) {
        emit(ScannerInitial());
      } else {
        emit(ScannerImagesPicked(
          images: updatedImages,
          suggestedName: currentState.suggestedName,
        ));
      }
    }
  }

  void _onReorderImages(ReorderImages event, Emitter<ScannerState> emit) {
    if (state is ScannerImagesPicked) {
      final currentState = state as ScannerImagesPicked;
      final updatedImages = List<File>.from(currentState.images);

      int newIndex = event.newIndex;
      if (event.oldIndex < newIndex) {
        newIndex -= 1;
      }
      final File image = updatedImages.removeAt(event.oldIndex);
      updatedImages.insert(newIndex, image);

      emit(ScannerImagesPicked(
        images: updatedImages,
        suggestedName: currentState.suggestedName,
      ));
    }
  }

  void _onUpdateImage(UpdateImage event, Emitter<ScannerState> emit) {
    if (state is ScannerImagesPicked) {
      final currentState = state as ScannerImagesPicked;
      final updatedImages = List<File>.from(currentState.images);
      updatedImages[event.index] = event.newImage;

      emit(ScannerImagesPicked(
        images: updatedImages,
        suggestedName: currentState.suggestedName,
      ));
    }
  }

  Future<void> _onSaveDocument(SaveDocument event, Emitter<ScannerState> emit) async {
    if (state is ScannerImagesPicked) {
      final currentState = state as ScannerImagesPicked;
      emit(ScannerLoading());
      try {
        final docId = await repository.createDocument(event.folderId, event.name);

        for (int i = 0; i < currentState.images.length; i++) {
          final permanentFile = await scannerService.saveImageToPermanentStorage(currentState.images[i]);
          await repository.addPage(PageModel(
            documentId: docId,
            imagePath: permanentFile.path,
            pageOrder: i,
          ));
        }

        emit(ScannerSaved());
      } catch (e) {
        emit(ScannerError(e.toString()));
      }
    }
  }
}