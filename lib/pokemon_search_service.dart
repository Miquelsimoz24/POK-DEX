import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'pokemon.dart';
import 'database_helper.dart';

class PokemonSearchService {
  static final PokemonSearchService _instance =
      PokemonSearchService._internal();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Pokemon>? _cachedPokemonList;

  factory PokemonSearchService() {
    return _instance;
  }

  PokemonSearchService._internal();

  Future<List<Pokemon>> searchPokemon(String query) async {
    if (_cachedPokemonList == null) {
      await _initializePokemonList();
    }

    if (query.isEmpty) {
      return [];
    }

    return _cachedPokemonList!
        .where((pokemon) =>
            pokemon.name.toLowerCase().contains(query.toLowerCase()) ||
            pokemon.id.toString().contains(query))
        .toList();
  }

  Future<void> _initializePokemonList() async {
    try {
      // Try to get from cache first
      final Database db = await _dbHelper.database;
      final List<Map<String, dynamic>> cachedData =
          await db.query('pokemon_list');

      if (cachedData.isNotEmpty) {
        _cachedPokemonList = cachedData
            .map((data) => Pokemon(
                  id: data['id'],
                  name: data['name'],
                  imageUrl: data['imageUrl'],
                  type: data['type'],
                ))
            .toList();
        return;
      }

      // If not in cache, fetch from API
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000&offset=0'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        _cachedPokemonList = [];
        final batch = db.batch();

        for (var pokemon in results) {
          final id = int.parse(pokemon['url'].toString().split('/')[6]);
          final newPokemon = Pokemon(
            id: id,
            name: pokemon['name'],
            imageUrl:
                'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
            type: '', // Will be fetched when needed
          );

          _cachedPokemonList!.add(newPokemon);

          batch.insert(
            'pokemon_list',
            {
              'id': id,
              'name': pokemon['name'],
              'imageUrl': newPokemon.imageUrl,
              'type': '',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit();
      }
    } catch (e) {
      print('Error initializing Pokemon list: $e');
      _cachedPokemonList = [];
    }
  }
}
