import '../core/database_helper.dart';
import '../models/folder_model.dart';
import '../models/document_model.dart';
import '../models/page_model.dart';

class DocumentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Folder>> getFolders() => _dbHelper.getAllFolders();

  Future<int> createFolder(String name) {
    final folder = Folder(name: name, createdAt: DateTime.now());
    return _dbHelper.insertFolder(folder);
  }

  Future<List<Document>> getRecentDocuments() => _dbHelper.getRecentDocuments();

  Future<List<Document>> getDocumentsInFolder(int folderId) =>
      _dbHelper.getDocumentsByFolder(folderId);

  Future<int> createDocument(int folderId, String name) {
    final doc = Document(
      folderId: folderId,
      name: name,
      createdAt: DateTime.now(),
    );
    return _dbHelper.insertDocument(doc);
  }

  Future<int> addPage(PageModel page) => _dbHelper.insertPage(page);

  Future<List<PageModel>> getPages(int documentId) =>
      _dbHelper.getPagesByDocument(documentId);

  Future<int> deleteDocument(int id) => _dbHelper.deleteDocument(id);

  Future<int> deleteFolder(int id) => _dbHelper.deleteFolder(id);

  Future<int> updatePage(PageModel page) => _dbHelper.updatePage(page);

  Future<int> deletePage(int id) => _dbHelper.deletePage(id);
}