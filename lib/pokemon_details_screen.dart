import 'package:flutter/material.dart';
import 'pokemon.dart';
import 'pokemon_details.dart';
import 'pokemon_service.dart';

class PokemonDetailsScreen extends StatelessWidget {
  final Pokemon pokemon;

  const PokemonDetailsScreen({super.key, required this.pokemon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pokemon.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.amber,
      ),
      body: FutureBuilder<PokemonDetalles>(
        future: PokemonService().fetchPokemonDetalles(pokemon.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error al cargar los detalles", style: TextStyle(fontSize: 18)));
          }

          final detalles = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.network(pokemon.imageUrl, height: 150),
                const SizedBox(height: 10),
                _buildTypeChips(detalles.tipos),
                const SizedBox(height: 20),
                _buildStatsCard(detalles.estadisticas),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeChips(List<String> tipos) {
    return Wrap(
      spacing: 8,
      children: tipos
          .map((tipo) => Chip(
        label: Text(tipo, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ))
          .toList(),
    );
  }

  Widget _buildStatsCard(Map<String, int> stats) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Estadísticas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            ...stats.entries.map(
                  (stat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(stat.key, style: const TextStyle(fontSize: 16)),
                    Text(stat.value.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
