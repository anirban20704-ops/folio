import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ScannerService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<List<File>> pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    return images.map((xFile) => File(xFile.path)).toList();
  }

  Future<File?> pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    return image != null ? File(image.path) : null;
  }

  Future<File> saveImageToPermanentStorage(File image) async {
    final directory = await getApplicationDocumentsDirectory();
    final folioDir = Directory(p.join(directory.path, 'scans'));

    if (!await folioDir.exists()) {
      await folioDir.create(recursive: true);
    }

    final String fileName =
        'IMG_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
    final File permanentImage = await image.copy(p.join(folioDir.path, fileName));
    return permanentImage;
  }

  /// Smart document name based on detected content keywords.
  Future<String> getSmartName(File image) async {
    final inputImage = InputImage.fromFile(image);
    final RecognizedText recognizedText =
    await _textRecognizer.processImage(inputImage);

    final text = recognizedText.text.toLowerCase();

    if (text.contains('invoice') || text.contains('bill')) {
      if (text.contains('amazon')) return 'Amazon_Invoice';
      if (text.contains('google')) return 'Google_Bill';
      return 'Invoice';
    }
    if (text.contains('passport')) return 'Passport_Scan';
    if (text.contains('id card') || text.contains('identification')) return 'ID_Card';
    if (text.contains('receipt')) return 'Receipt';
    if (text.contains('contract') || text.contains('agreement')) return 'Contract';
    if (text.contains('certificate')) return 'Certificate';

    return 'New_Document';
  }

  /// Full OCR text extraction from a single image file.
  /// Returns recognized text, or empty string if nothing found.
  Future<String> extractTextFromImage(File image) async {
    try {
      final inputImage = InputImage.fromFile(image);
      final RecognizedText recognizedText =
      await _textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } catch (e) {
      return '';
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
