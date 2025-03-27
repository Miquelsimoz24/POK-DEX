import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pokemon.dart';
import 'pokemon_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final List<Pokemon> allPokemon;

  const FavoritesScreen({super.key, required this.allPokemon});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Set<int> _favoritePokemonIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoritePokemonIds =
          prefs.getStringList('favorites')?.map(int.parse).toSet() ?? {};
    });
  }

  Future<void> _toggleFavorite(int pokemonId) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _favoritePokemonIds.remove(pokemonId);
    });

    await prefs.setStringList(
      'favorites',
      _favoritePokemonIds.map((id) => id.toString()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoritePokemon = widget.allPokemon
        .where((p) => _favoritePokemonIds.contains(p.id))
        .toList();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true); // Return true to indicate changes
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pokémon Favoritos'),
          backgroundColor: Colors.amber,
        ),
        body: favoritePokemon.isEmpty
            ? const Center(child: Text('No tienes Pokémon favoritos aún.'))
            : ListView.builder(
                itemCount: favoritePokemon.length,
                itemBuilder: (context, index) {
                  final pokemon = favoritePokemon[index];
                  return ListTile(
                    leading:
                        Image.network(pokemon.imageUrl, width: 50, height: 50),
                    title: Text("#${pokemon.id} ${pokemon.name.toUpperCase()}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => _toggleFavorite(pokemon.id),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PokemonDetailsScreen(pokemon: pokemon),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
