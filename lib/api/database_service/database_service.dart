import 'package:chat_app/models/message_model.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  // Bumped from 1 -> 2 to add attachment/reaction/edit/delete/read columns.
  static const int _dbVersion = 2;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'chat_app.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (database, version) async {
        await database.execute(_createTableSql);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            "ALTER TABLE messages ADD COLUMN fileType TEXT DEFAULT 'text'",
          );
          await database.execute(
            "ALTER TABLE messages ADD COLUMN fileUrl TEXT DEFAULT ''",
          );
          await database.execute(
            "ALTER TABLE messages ADD COLUMN fileName TEXT DEFAULT ''",
          );
          await database.execute(
            "ALTER TABLE messages ADD COLUMN reactions TEXT DEFAULT '{}'",
          );
          await database.execute(
            'ALTER TABLE messages ADD COLUMN isEdited INTEGER DEFAULT 0',
          );
          await database.execute(
            'ALTER TABLE messages ADD COLUMN isDeleted INTEGER DEFAULT 0',
          );
          await database.execute(
            'ALTER TABLE messages ADD COLUMN editedAt INTEGER',
          );
          await database.execute(
            'ALTER TABLE messages ADD COLUMN readAt INTEGER',
          );
        }
      },
    );
  }

  static const String _createTableSql = '''
    CREATE TABLE messages (
      id TEXT PRIMARY KEY,
      senderId TEXT NOT NULL,
      receiverId TEXT NOT NULL,
      text TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      messageStatus TEXT DEFAULT 'pending',
      isSynced INTEGER DEFAULT 0,
      fileType TEXT DEFAULT 'text',
      fileUrl TEXT DEFAULT '',
      fileName TEXT DEFAULT '',
      reactions TEXT DEFAULT '{}',
      isEdited INTEGER DEFAULT 0,
      isDeleted INTEGER DEFAULT 0,
      editedAt INTEGER,
      readAt INTEGER
    )
  ''';

  Future<int> addMessage(Message message) async {
    try {
      return await (await database).insert(
        'messages',
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (error) {
      debugPrint('Error adding message: $error');
      return -1;
    }
  }

  Future<List<Message>> getMessages(String senderId, String receiverId) async {
    try {
      final rows = await (await database).query(
        'messages',
        where:
            '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)',
        whereArgs: [senderId, receiverId, receiverId, senderId],
        orderBy: 'timestamp ASC',
      );
      return rows.map(Message.fromMap).toList();
    } catch (error) {
      debugPrint('Error loading messages: $error');
      return [];
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
