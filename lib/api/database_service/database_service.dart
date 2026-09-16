import 'package:chat_app/models/message_model.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'chat_app.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            senderId TEXT NOT NULL,
            receiverId TEXT NOT NULL,
            text TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            messageStatus TEXT DEFAULT 'pending',
            isSynced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

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
