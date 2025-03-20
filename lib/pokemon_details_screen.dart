import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'pokemon.dart';
import 'pokemon_details.dart';
import 'pokemon_audio_service.dart';

extension ColorExtension on Color {
  Color darker([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

class PokemonDetailsScreen extends StatefulWidget {
  final Pokemon pokemon;

  const PokemonDetailsScreen({Key? key, required this.pokemon})
      : super(key: key);

  @override
  State<PokemonDetailsScreen> createState() => _PokemonDetailsScreenState();
}

class _PokemonDetailsScreenState extends State<PokemonDetailsScreen> {
  late Future<PokemonDetalles> _pokemonDetalles;
  bool _isPlayingSound = false;

  final Map<String, String> typeTranslations = {
    "normal": "Normal",
    "fire": "Fuego",
    "water": "Agua",
    "grass": "Planta",
    "electric": "Eléctrico",
    "ice": "Hielo",
    "fighting": "Lucha",
    "poison": "Veneno",
    "ground": "Tierra",
    "flying": "Volador",
    "psychic": "Psíquico",
    "bug": "Bicho",
    "rock": "Roca",
    "ghost": "Fantasma",
    "dark": "Siniestro",
    "dragon": "Dragón",
    "steel": "Acero",
    "fairy": "Hada",
  };

  final Map<String, Color> typeColors = {
    "normal": const Color(0xFFA8A878),
    "fire": const Color(0xFFF08030),
    "water": const Color(0xFF6890F0),
    "grass": const Color(0xFF78C850),
    "electric": const Color(0xFFF8D030),
    "ice": const Color(0xFF98D8D8),
    "fighting": const Color(0xFFC03028),
    "poison": const Color(0xFFA040A0),
    "ground": const Color(0xFFE0C068),
    "flying": const Color(0xFFA890F0),
    "psychic": const Color(0xFFF85888),
    "bug": const Color(0xFFA8B820),
    "rock": const Color(0xFFB8A038),
    "ghost": const Color(0xFF705898),
    "dark": const Color(0xFF705848),
    "dragon": const Color(0xFF7038F8),
    "steel": const Color(0xFFB8B8D0),
    "fairy": const Color(0xFFEE99AC),
  };

  @override
  void initState() {
    super.initState();
    _pokemonDetalles = _loadPokemonDetails();
  }

  Future<PokemonDetalles> _loadPokemonDetails() async {
    try {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon.id}'),
      );

      if (response.statusCode == 200) {
        return PokemonDetalles.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Error ${response.statusCode}: Failed to load pokemon details');
      }
    } catch (e) {
      print('Error loading details: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("#${widget.pokemon.id} ${widget.pokemon.name}"),
      ),
      body: FutureBuilder<PokemonDetalles>(
        future: _pokemonDetalles,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildPokemonImage(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: _buildTypeChips(snapshot.data!.tipos),
                  ),
                  _buildStats(snapshot.data!),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildPokemonImage() {
    return GestureDetector(
      onTap: () async {
        setState(() => _isPlayingSound = true);
        await PokemonAudioService.playPokemonCry(widget.pokemon.id);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() => _isPlayingSound = false);
        }
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Hero(
            tag: 'pokemon-${widget.pokemon.id}',
            child: Image.network(
              widget.pokemon.imageUrl,
              height: 200,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              _isPlayingSound ? Icons.volume_up : Icons.volume_up_outlined,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChips(List<String> tipos) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: tipos.map((tipo) {
        final spanishType = typeTranslations[tipo.toLowerCase()] ?? tipo;
        final typeColor = typeColors[tipo.toLowerCase()] ?? Colors.grey;

        return Chip(
          label: Text(
            spanishType,
            style: TextStyle(
              color: typeColor.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: typeColor,
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStats(PokemonDetalles detalles) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...detalles.estadisticas.entries.map((stat) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: stat.value / 255.0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getStatColor(stat.value),
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            stat.value.toString(),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getStatColor(int value) {
    if (value >= 150) return Colors.green;
    if (value >= 90) return Colors.amber;
    return Colors.red;
  }
}
