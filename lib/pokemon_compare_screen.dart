import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'pokemon.dart';
import 'pokemon_service.dart';
import 'pokemon_loading_animation.dart';
import 'pokemon_details.dart';

class PokemonCompareScreen extends StatefulWidget {
  final List<Pokemon> allPokemon;

  const PokemonCompareScreen({Key? key, required this.allPokemon})
      : super(key: key);

  @override
  _PokemonCompareScreenState createState() => _PokemonCompareScreenState();
}

class _PokemonCompareScreenState extends State<PokemonCompareScreen> {
  Pokemon? pokemon1;
  Pokemon? pokemon2;
  PokemonDetalles? detalles1;
  PokemonDetalles? detalles2;
  List<Pokemon> _allPokemon = [];
  final PokemonService _pokemonService = PokemonService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllPokemon();
  }

  Future<void> _loadAllPokemon() async {
    setState(() => _isLoading = true);
    try {
      final pokemonService = PokemonService();
      _allPokemon = await pokemonService.getAllPokemonForComparison();
    } catch (e) {
      print('Error loading Pokemon: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectPokemon(Pokemon pokemon, bool isFirst) async {
    setState(() => _isLoading = true);
    try {
      final details = await _pokemonService.fetchPokemonDetalles(pokemon.id);
      if (mounted) {
        setState(() {
          if (isFirst) {
            pokemon1 = pokemon;
            detalles1 = details;
          } else {
            pokemon2 = pokemon;
            detalles2 = details;
          }
        });
      }
    } catch (e) {
      print('Error loading Pokemon details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar detalles del Pokémon')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPokemonSelector(bool isFirst) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(isFirst ? 'Pokémon 1' : 'Pokémon 2'),
            const SizedBox(height: 8),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              DropdownButton<Pokemon>(
                value: isFirst ? pokemon1 : pokemon2,
                hint: const Text('Seleccionar'),
                isExpanded: true,
                items: _allPokemon
                    .map((pokemon) => DropdownMenuItem(
                          value: pokemon,
                          child: Text(
                              "#${pokemon.id} ${pokemon.name.toUpperCase()}"),
                        ))
                    .toList(),
                onChanged: (Pokemon? value) {
                  if (value != null) {
                    _selectPokemon(value, isFirst);
                  }
                },
              ),
            if ((isFirst ? pokemon1 : pokemon2) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Image.network(
                  (isFirst ? pokemon1 : pokemon2)!.imageUrl,
                  height: 100,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const CircularProgressIndicator();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatComparison(String statName, int value1, int value2) {
    final maxValue = 255.0;
    final percentage1 = value1 / maxValue;
    final percentage2 = value2 / maxValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(
            statName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage1,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    value1 >= value2 ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$value1'),
              const SizedBox(width: 16),
              Text('$value2'),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage2,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    value2 >= value1 ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar Pokémon'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: _buildPokemonSelector(true)),
                const SizedBox(width: 16),
                Expanded(child: _buildPokemonSelector(false)),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: PokemonLoadingAnimation(
                  size: 100.0,
                  color: Colors.red,
                ),
              ),
            )
          else if (pokemon1 != null &&
              pokemon2 != null &&
              detalles1 != null &&
              detalles2 != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatComparison('PS', detalles1!.estadisticas['PS']!,
                        detalles2!.estadisticas['PS']!),
                    _buildStatComparison(
                        'Ataque',
                        detalles1!.estadisticas['Ataque']!,
                        detalles2!.estadisticas['Ataque']!),
                    _buildStatComparison(
                        'Defensa',
                        detalles1!.estadisticas['Defensa']!,
                        detalles2!.estadisticas['Defensa']!),
                    _buildStatComparison(
                        'Ataque Especial',
                        detalles1!.estadisticas['Ataque Especial']!,
                        detalles2!.estadisticas['Ataque Especial']!),
                    _buildStatComparison(
                        'Defensa Especial',
                        detalles1!.estadisticas['Defensa Especial']!,
                        detalles2!.estadisticas['Defensa Especial']!),
                    _buildStatComparison(
                        'Velocidad',
                        detalles1!.estadisticas['Velocidad']!,
                        detalles2!.estadisticas['Velocidad']!),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
