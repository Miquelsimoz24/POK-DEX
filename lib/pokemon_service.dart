import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'pokemon.dart';
import 'pokemon_details.dart';
import 'database_helper.dart';

class PokemonServiceException implements Exception {
  final String message;
  final String? technicalDetails;

  PokemonServiceException(this.message, {this.technicalDetails});

  @override
  String toString() => message;
}

class PokemonService {
  static const int pokemonPerPage = 30; // Make public
  static const int totalPokemon = 1025; // Keep total up to date
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Pokemon>> fetchPokemon(int offset) async {
    try {
      // First try cache
      final cachedPokemon =
          await _dbHelper.getCachedPokemon(offset, pokemonPerPage);
      if (cachedPokemon.length == pokemonPerPage) {
        return cachedPokemon;
      }

      final response = await http
          .get(
            Uri.parse(
                'https://pokeapi.co/api/v2/pokemon?limit=$pokemonPerPage&offset=$offset'),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('La conexión está tardando demasiado'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Pokemon> pokemonList = [];
        final List<Future<void>> futures = [];

        for (var item in data['results']) {
          final id = int.parse(item['url'].toString().split('/')[6]);
          if (id <= totalPokemon) {
            // Only process Pokemon up to 1025
            futures.add(_fetchPokemonDetails(id, item['name']).then((pokemon) {
              if (pokemon != null) {
                pokemonList.add(pokemon);
                _dbHelper.insertPokemon(pokemon);
              }
            }));
          }
        }

        await Future.wait(futures);
        return pokemonList..sort((a, b) => a.id.compareTo(b.id));
      } else {
        throw PokemonServiceException(
          'Error del servidor',
          technicalDetails: 'HTTP Status: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw PokemonServiceException(
        'No hay conexión a internet',
        technicalDetails: 'No se pudo conectar al servidor',
      );
    } on TimeoutException {
      throw PokemonServiceException(
        'La conexión está tardando demasiado',
        technicalDetails: 'La solicitud ha excedido el tiempo de espera',
      );
    } catch (e) {
      throw PokemonServiceException(
        'Ha ocurrido un error inesperado',
        technicalDetails: e.toString(),
      );
    }
  }

  Future<Pokemon?> _fetchPokemonDetails(int id, String name) async {
    if (id > totalPokemon) return null;

    try {
      final response = await http
          .get(
            Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Pokemon(
          id: id,
          name: name,
          imageUrl: data['sprites']['front_default'] ??
              'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
          type: data['types'][0]['type']['name'],
        );
      }
      return null;
    } catch (e) {
      print('Error fetching Pokemon details for ID $id: $e');
      return null;
    }
  }

  Future<PokemonDetalles> fetchPokemonDetalles(int id) async {
    try {
      // Check cache first
      final cachedDetails = await _dbHelper.getPokemonDetails(id);
      final shouldRefresh = await _dbHelper.shouldRefreshCache(id);

      if (cachedDetails != null && !shouldRefresh) {
        print('✅ Returning cached details for Pokemon: $id');
        return PokemonDetalles.fromJson({
          'stats': cachedDetails['stats'],
          'types': cachedDetails['types'],
        });
      }

      final response =
          await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Cache the details
        await _dbHelper.insertPokemon(
          Pokemon(
            id: id,
            name: data['name'],
            imageUrl:
                'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
            type: data['types'][0]['type']['name'],
          ),
          details: {
            'stats': data['stats'],
            'types': data['types'],
          },
        );

        return PokemonDetalles.fromJson(data);
      }
      throw Exception('Failed to load pokemon details');
    } catch (e) {
      print('Error fetching Pokemon details: $e');
      // Try to return cached details even if they're old
      final cachedDetails = await _dbHelper.getPokemonDetails(id);
      if (cachedDetails != null) {
        return PokemonDetalles.fromJson({
          'stats': cachedDetails['stats'],
          'types': cachedDetails['types'],
        });
      }
      rethrow;
    }
  }

  Future<List<Pokemon>> fetchPokemonList() async {
    return fetchPokemon(
        0); // Fetch first batch of Pokemon starting from offset 0
  }

  Future<Pokemon> fetchRandomPokemon() async {
    final random = Random();
    final randomId = random.nextInt(totalPokemon) + 1;

    try {
      final response = await http
          .get(
            Uri.parse('https://pokeapi.co/api/v2/pokemon/$randomId'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Pokemon(
          id: randomId,
          name: data['name'],
          imageUrl:
              'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$randomId.png',
          type: data['types'][0]['type']['name'],
        );
      } else {
        throw PokemonServiceException(
          'Error al cargar el Pokémon aleatorio',
          technicalDetails: 'HTTP Status: ${response.statusCode}',
        );
      }
    } on http.ClientException {
      throw PokemonServiceException(
        'No hay conexión a internet',
        technicalDetails: 'Cliente HTTP error',
      );
    } on TimeoutException {
      throw PokemonServiceException(
        'La conexión está tardando demasiado',
        technicalDetails: 'Timeout error',
      );
    } catch (e) {
      print("❌ Error al obtener Pokémon aleatorio: $e");
      throw PokemonServiceException(
        'Ha ocurrido un error inesperado',
        technicalDetails: e.toString(),
      );
    }
  }

  Future<List<Pokemon>> searchPokemon(String query) async {
    try {
      // First try to get from cache
      final cachedResults = await _dbHelper.searchPokemon(query);
      if (cachedResults.isNotEmpty) {
        return cachedResults;
      }

      final response = await http.get(
        Uri.parse(
            'https://pokeapi.co/api/v2/pokemon?limit=1500&offset=0'), // Increased limit
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        // Filter Pokemon by query, including special forms
        final filteredResults = results.where((pokemon) {
          final name = pokemon['name'] as String;
          // Include all forms in search (regular, gmax, mega, etc)
          return name.toLowerCase().contains(query.toLowerCase());
        }).toList();

        // Convert results to Pokemon objects
        final List<Pokemon> searchResults = [];
        for (var pokemon in filteredResults) {
          try {
            final id = int.parse(pokemon['url'].toString().split('/')[6]);
            final detailsResponse = await http
                .get(
                  Uri.parse(
                      'https://pokeapi.co/api/v2/pokemon/${pokemon['name']}'),
                )
                .timeout(const Duration(seconds: 10));

            if (detailsResponse.statusCode == 200) {
              final detailsData = json.decode(detailsResponse.body);
              final String imageUrl = detailsData['sprites']['front_default'] ??
                  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';

              final newPokemon = Pokemon(
                id: id,
                name: pokemon['name'],
                imageUrl: imageUrl,
                type: detailsData['types'][0]['type']['name'],
              );

              searchResults.add(newPokemon);

              // Cache the Pokemon
              await _dbHelper.insertPokemon(
                newPokemon,
                details: {
                  'stats': detailsData['stats'],
                  'types': detailsData['types'],
                },
              );
            }
          } catch (e) {
            print('Error fetching details for Pokemon ${pokemon['name']}: $e');
            continue;
          }
        }

        return searchResults..sort((a, b) => a.id.compareTo(b.id));
      }
      return [];
    } catch (e) {
      print('Error searching Pokemon: $e');
      // Try to return cached results on error
      return _dbHelper.searchPokemon(query);
    }
  }

  Future<List<Pokemon>> fetchPokemonBatch(List<int> ids) async {
    List<Pokemon> pokemons = [];
    for (var id in ids) {
      try {
        final response =
            await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          pokemons.add(Pokemon(
            id: data['id'],
            name: data['name'],
            imageUrl: data['sprites']['front_default'],
            type: data['types'][0]['type']['name'],
          ));
        }
      } catch (e) {
        print('Error fetching Pokemon $id: $e');
      }
    }
    return pokemons;
  }

  Future<bool> hasMorePokemon(int currentOffset) async {
    return currentOffset < totalPokemon;
  }

  Future<List<Pokemon>> getAllPokemonForComparison() async {
    try {
      // First try to get from cache
      final cachedPokemon = await _dbHelper.getAllPokemon();
      if (cachedPokemon.length >= totalPokemon) {
        return cachedPokemon;
      }

      final response = await http
          .get(
            Uri.parse(
                'https://pokeapi.co/api/v2/pokemon?limit=$totalPokemon&offset=0'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        final List<Pokemon> pokemonList = [];

        // Process in smaller batches to avoid overwhelming the API
        for (int i = 0; i < results.length; i += 5) {
          final batch = results.skip(i).take(5);
          final futures = batch.map((pokemon) async {
            try {
              final id = int.parse(pokemon['url'].toString().split('/')[6]);
              if (id > totalPokemon) return null;

              final detailsResponse = await http
                  .get(
                    Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'),
                  )
                  .timeout(const Duration(seconds: 15));

              if (detailsResponse.statusCode == 200) {
                final detailsData = json.decode(detailsResponse.body);
                final newPokemon = Pokemon(
                  id: id,
                  name: pokemon['name'],
                  imageUrl: detailsData['sprites']['front_default'] ??
                      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
                  type: detailsData['types'][0]['type']['name'],
                );

                // Cache immediately
                await _dbHelper.insertPokemon(
                  newPokemon,
                  details: {
                    'stats': detailsData['stats'],
                    'types': detailsData['types'],
                  },
                );

                return newPokemon;
              }
            } catch (e) {
              print('Error fetching Pokemon $pokemon: $e');
            }
            return null;
          });

          final batchResults = await Future.wait(futures);
          pokemonList.addAll(batchResults.whereType<Pokemon>());
        }

        return pokemonList..sort((a, b) => a.id.compareTo(b.id));
      }
      throw PokemonServiceException('Error al cargar los Pokemon');
    } catch (e) {
      print('Error loading all Pokemon: $e');
      // Return cached Pokemon on error
      return _dbHelper.getAllPokemon();
    }
  }
}
