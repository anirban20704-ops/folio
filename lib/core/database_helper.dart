import 'package:path/path.dart';
import 'package:pdf/widgets.dart' hide Document;
import 'package:sqflite/sqflite.dart';
import '../models/folder_model.dart';
import '../models/document_model.dart';
import '../models/page_model.dart';
import '../models/task_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('folio.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTasksTable(db); // already includes the deadline column
    } else if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN deadline TEXT');
    }
  }

  Future _createTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        imagePaths TEXT,
        isDone INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        deadline TEXT
      )
    ''');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folderId INTEGER NOT NULL,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        documentId INTEGER NOT NULL,
        imagePath TEXT NOT NULL,
        pageOrder INTEGER NOT NULL,
        metadata TEXT,
        FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');

    await _createTasksTable(db);

    // Insert a default "Uncategorized" folder
    await db.insert('folders', {
      'name': 'Uncategorized',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // Folder CRUD
  Future<int> insertFolder(Folder folder) async {
    final db = await instance.database;
    return await db.insert('folders', folder.toMap());
  }

  Future<List<Folder>> getAllFolders() async {
    final db = await instance.database;
    final result = await db.query('folders', orderBy: 'createdAt DESC');
    return result.map((json) => Folder.fromMap(json)).toList();
  }

  // Document CRUD
  Future<int> insertDocument(Document doc) async {
    final db = await instance.database;
    return await db.insert('documents', doc.toMap());
  }

  Future<List<Document>> getDocumentsByFolder(int folderId) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'folderId = ?',
      whereArgs: [folderId],
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => Document.fromMap(json)).toList();
  }

  Future<List<Document>> getRecentDocuments({int limit = 5}) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return result.map((json) => Document.fromMap(json)).toList();
  }

  Future<int> deleteDocument(int id) async {
    final db = await instance.database;
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFolder(int id) async {
    final db = await instance.database;
    return await db.delete(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Page CRUD
  Future<int> insertPage(PageModel page) async {
    final db = await instance.database;
    return await db.insert('pages', page.toMap());
  }

  Future<List<PageModel>> getPagesByDocument(int documentId) async {
    final db = await instance.database;
    final result = await db.query(
      'pages',
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'pageOrder ASC',
    );
    return result.map((json) => PageModel.fromMap(json)).toList();
  }

  Future<int> updatePage(PageModel page) async {
    final db = await instance.database;
    return await db.update(
      'pages',
      page.toMap(),
      where: 'id = ?',
      whereArgs: [page.id],
    );
  }

  Future<int> deletePage(int id) async {
    final db = await instance.database;
    return await db.delete(
      'pages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Task CRUD
  Future<int> insertTask(TaskItem task) async {
    final db = await instance.database;
    final map = task.toMap()..remove('id');
    return await db.insert('tasks', map);
  }

  Future<List<TaskItem>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', orderBy: 'createdAt DESC');
    return result.map((json) => TaskItem.fromMap(json)).toList();
  }

  Future<int> setTaskDone(int id, bool done) async {
    final db = await instance.database;
    return await db.update('tasks', {'isDone': done ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> setTaskDeadline(int id, DateTime? deadline) async {
    final db = await instance.database;
    return await db.update('tasks', {'deadline': deadline?.toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCompletedTasks() async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'isDone = 1');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}