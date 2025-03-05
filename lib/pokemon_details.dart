class PokemonDetalles {
  final List<String> tipos;
  final Map<String, int> estadisticas;

  PokemonDetalles({required this.tipos, required this.estadisticas});

  factory PokemonDetalles.fromJson(Map<String, dynamic> json) {
    List<String> tipos = (json['types'] as List)
        .map((t) => t['type']['name'].toString())
        .toList();

    Map<String, int> estadisticas = {
      "PS": json['stats'][0]['base_stat'], // HP
      "Ataque": json['stats'][1]['base_stat'],
      "Defensa": json['stats'][2]['base_stat'],
      "Ataque Especial": json['stats'][3]['base_stat'],
      "Defensa Especial": json['stats'][4]['base_stat'],
      "Velocidad": json['stats'][5]['base_stat'],
    };

    return PokemonDetalles(tipos: tipos, estadisticas: estadisticas);
  }
}
