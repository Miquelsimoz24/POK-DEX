import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'pokemon.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'pokemon_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE pokemon_list(
            id INTEGER PRIMARY KEY,
            name TEXT,
            imageUrl TEXT,
            type TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pokemon(
            id INTEGER PRIMARY KEY,
            name TEXT,
            imageUrl TEXT,
            type TEXT,
            stats TEXT,
            types TEXT,
            last_updated INTEGER
          )
        ''');
      },
    );
  }

  Future<void> insertPokemon(Pokemon pokemon,
      {Map<String, dynamic>? details}) async {
    final Database db = await database;
    await db.insert(
      'pokemon',
      {
        'id': pokemon.id,
        'name': pokemon.name,
        'imageUrl': pokemon.imageUrl,
        'type': pokemon.type,
        'stats': details != null ? json.encode(details['stats']) : null,
        'types': details != null ? json.encode(details['types']) : null,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Pokemon>> getCachedPokemon(int offset, int limit) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pokemon',
      limit: limit,
      offset: offset,
      orderBy: 'id ASC',
    );

    return List.generate(maps.length, (i) {
      return Pokemon(
        id: maps[i]['id'],
        name: maps[i]['name'],
        imageUrl: maps[i]['imageUrl'],
        type: maps[i]['type'],
      );
    });
  }

  Future<Map<String, dynamic>?> getPokemonDetails(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'pokemon',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      final data = result.first;
      if (data['stats'] != null && data['types'] != null) {
        return {
          'stats': json.decode(data['stats']),
          'types': json.decode(data['types']),
        };
      }
    }
    return null;
  }

  Future<bool> shouldRefreshCache(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'pokemon',
      columns: ['last_updated'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return true;

    final lastUpdated = DateTime.fromMillisecondsSinceEpoch(
        result.first['last_updated'] as int);
    final now = DateTime.now();
    return now.difference(lastUpdated).inHours >
        24; // Refresh cache after 24 hours
  }

  Future<bool> isPokemonCached(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'pokemon',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }

  Future<List<Pokemon>> searchPokemon(String query) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pokemon',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'id ASC',
    );

    return List.generate(maps.length, (i) {
      return Pokemon(
        id: maps[i]['id'],
        name: maps[i]['name'],
        imageUrl: maps[i]['imageUrl'],
        type: maps[i]['type'],
      );
    });
  }

  Future<List<Pokemon>> getAllPokemon() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pokemon',
      orderBy: 'id ASC',
    );

    return List.generate(maps.length, (i) {
      return Pokemon(
        id: maps[i]['id'],
        name: maps[i]['name'],
        imageUrl: maps[i]['imageUrl'],
        type: maps[i]['type'],
      );
    });
  }
}
