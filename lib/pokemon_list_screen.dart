import 'package:flutter/material.dart';
import 'pokemon_service.dart';
import 'pokemon.dart';
import 'pokemon_details_screen.dart';

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({super.key});

  @override
  _PokemonListScreenState createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  final PokemonService _pokemonService = PokemonService();
  List<Pokemon> _pokemonList = [];
  List<Pokemon> _filteredPokemonList = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  Future<void> _loadPokemon() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final pokemon = await _pokemonService.fetchPokemonList();
      setState(() {
        _pokemonList = pokemon;
        _filteredPokemonList = pokemon;
      });
    } catch (e) {
      setState(() => _hasError = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterPokemon(String query) {
    setState(() {
      _filteredPokemonList = _pokemonList
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[100],
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: const Center(
          child: Text(
            'La Pokédex',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _filterPokemon,
              decoration: const InputDecoration(
                labelText: 'Buscar Pokémon',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                ? const Center(child: Text('Error al cargar los datos'))
                : ListView.builder(
              itemCount: _filteredPokemonList.length,
              itemBuilder: (context, index) {
                final pokemon = _filteredPokemonList[index];
                return ListTile(
                  leading: Image.network(pokemon.imageUrl, width: 50, height: 50),
                  title: Text("#${pokemon.id} ${pokemon.name.toUpperCase()}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PokemonDetailsScreen(pokemon: pokemon),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
