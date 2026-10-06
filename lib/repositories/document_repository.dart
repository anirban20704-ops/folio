import '../core/database_helper.dart';
import '../models/folder_model.dart';
import '../models/document_model.dart';
import '../models/page_model.dart';
import '../services/notification_service.dart';

class DocumentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService.instance;

  Future<List<Folder>> getFolders() => _dbHelper.getAllFolders();

  Future<int> createFolder(String name) {
    final folder = Folder(name: name, createdAt: DateTime.now());
    return _dbHelper.insertFolder(folder);
  }

  Future<List<Document>> getRecentDocuments() => _dbHelper.getRecentDocuments();

  Future<List<Document>> getDocumentsInFolder(int folderId) =>
      _dbHelper.getDocumentsByFolder(folderId);

  /// A document has no deadline unless one is explicitly given here -
  /// nothing is auto-filled. [notifyEnabled] only takes effect when
  /// [deadline] is actually set; the UI keeps the toggle off otherwise.
  Future<int> createDocument(
    int folderId,
    String name, {
    DateTime? deadline,
    bool notifyEnabled = false,
  }) async {
    final effectiveNotify = deadline != null && notifyEnabled;
    final doc = Document(
      folderId: folderId,
      name: name,
      createdAt: DateTime.now(),
      deadline: deadline,
      notifyEnabled: effectiveNotify,
    );
    final id = await _dbHelper.insertDocument(doc);
    await _notifications.scheduleForDocument(
      id: id,
      title: name,
      at: deadline,
      enabled: effectiveNotify,
    );
    return id;
  }

  /// Updates just a document's deadline/notification toggle, from the
  /// document detail screen (set it after the document already exists).
  Future<void> updateDeadline(
    Document original, {
    DateTime? deadline,
    required bool notifyEnabled,
  }) async {
    final effectiveNotify = deadline != null && notifyEnabled;
    await _dbHelper.updateDocument(original.copyWith(
      deadline: deadline,
      clearDeadline: deadline == null,
      notifyEnabled: effectiveNotify,
    ));
    await _notifications.scheduleForDocument(
      id: original.id!,
      title: original.name,
      at: deadline,
      enabled: effectiveNotify,
    );
  }

  Future<int> addPage(PageModel page) => _dbHelper.insertPage(page);

  Future<List<PageModel>> getPages(int documentId) =>
      _dbHelper.getPagesByDocument(documentId);

  Future<int> deleteDocument(int id) async {
    final result = await _dbHelper.deleteDocument(id);
    await _notifications.cancelForDocument(id);
    return result;
  }

  Future<int> deleteFolder(int id) async {
    // Deleting a folder cascades to its documents, so cancel their reminders.
    final docs = await _dbHelper.getDocumentsByFolder(id);
    final result = await _dbHelper.deleteFolder(id);
    for (final d in docs) {
      if (d.id != null) await _notifications.cancelForDocument(d.id!);
    }
    return result;
  }

  Future<int> updatePage(PageModel page) => _dbHelper.updatePage(page);

  Future<int> deletePage(int id) => _dbHelper.deletePage(id);
}
