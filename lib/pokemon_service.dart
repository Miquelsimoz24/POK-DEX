import 'dart:convert';
import 'package:http/http.dart' as http;
import 'pokemon.dart';
import 'pokemon_details.dart';

class PokemonService {
  Future<List<Pokemon>> fetchPokemonList() async {
    List<Pokemon> pokemonList = [];
    String url = 'https://pokeapi.co/api/v2/pokemon?limit=2000'; // Obtener TODOS los Pokémon

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        for (var item in data['results']) {
          int id = int.parse(item['url'].split('/')[6]);
          pokemonList.add(Pokemon(
            id: id,
            name: item['name'],
            imageUrl:
            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
          ));
        }
        return pokemonList;
      } else {
        throw Exception('Error al cargar los datos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<PokemonDetalles> fetchPokemonDetalles(int id) async {
    final url = 'https://pokeapi.co/api/v2/pokemon/$id';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PokemonDetalles.fromJson(data);
      } else {
        throw Exception('Error al cargar detalles del Pokémon');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
