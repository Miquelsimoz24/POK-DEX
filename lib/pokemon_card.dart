import 'package:flutter/material.dart';
import 'pokemon.dart';
import 'pokemon_details_screen.dart';

class PokemonCard extends StatelessWidget {
  final Pokemon pokemon;

  const PokemonCard({super.key, required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final Map<String, Color> typeColors = {
      "fire": Colors.redAccent,
      "water": Colors.blueAccent,
      "grass": Colors.green,
      "electric": Colors.yellow,
      "psychic": Colors.purple,
      "ice": Colors.cyanAccent,
      "dragon": Colors.indigo,
      "dark": Colors.black54,
      "fairy": Colors.pinkAccent,
      "normal": Colors.grey,
      "fighting": Colors.brown,
      "flying": Colors.lightBlueAccent,
      "poison": Colors.deepPurple,
      "ground": Colors.orange,
      "rock": Colors.brown.shade700,
      "bug": Colors.lightGreen,
      "ghost": Colors.indigo.shade400,
      "steel": Colors.blueGrey,
    };

    Color borderColor = typeColors[pokemon.type] ?? Colors.grey;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 3),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PokemonDetailsScreen(pokemon: pokemon)),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(pokemon.imageUrl, width: 80, height: 80),
            const SizedBox(height: 8),
            Text("#${pokemon.id} ${pokemon.name.toUpperCase()}"),
          ],
        ),
      ),
    );
  }
}
