import 'package:flutter/material.dart';
import 'pokemon_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokedexApp());
}

class PokedexApp extends StatefulWidget {
  const PokedexApp({super.key});

  @override
  _PokedexAppState createState() => _PokedexAppState();
}

class _PokedexAppState extends State<PokedexApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'La Pokédex',
      theme: _isDarkMode ? _darkTheme : _lightTheme,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0,
          ),
          child: child!,
        );
      },
      home:
          PokemonListScreen(toggleTheme: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  primaryColor: Colors.amber,
  scaffoldBackgroundColor: Colors.yellow[100],
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.amber,
    iconTheme: IconThemeData(color: Colors.black87),
    actionsIconTheme: IconThemeData(color: Colors.black87),
    elevation: 0,
  ),
  iconTheme: const IconThemeData(
    color: Colors.black87,
    size: 24.0,
  ),
);

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: Colors.deepOrange,
  scaffoldBackgroundColor: Colors.black87,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.deepOrange,
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
    elevation: 0,
  ),
  iconTheme: const IconThemeData(
    color: Colors.white,
    size: 24.0,
  ),
);
