class Pokemon {
  final int id;
  final String name;
  final String type;
  final String imageUrl;

  Pokemon({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      id: json['id'],
      name: json['name'],
      type: json['type'], // Se usa el tipo correcto
      imageUrl: json['imageUrl'],
    );
  }
}
