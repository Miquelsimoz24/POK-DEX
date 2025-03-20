import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pokemon_service.dart';
import 'pokemon.dart';
import 'pokemon_details_screen.dart';
import 'favorites_screen.dart';
import 'dart:math';
import 'dart:async';
import 'pokemon_loading_animation.dart';
import 'pokemon_compare_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'error_widgets.dart';

// Add this enum at the top of the file, after the imports
enum SortOrder {
  numberAsc,
  numberDesc,
  nameAsc,
  nameDesc,
}

class PokemonListScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const PokemonListScreen(
      {super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  _PokemonListScreenState createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  final PokemonService _pokemonService = PokemonService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<Pokemon> _pokemonList = [];
  List<Pokemon> _filteredPokemonList = [];
  Set<int> _favoritePokemonIds = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentOffset = 0;
  bool _isGridView = false;
  String? _selectedType = "Todos";
  SortOrder _currentSort = SortOrder.numberAsc;
  bool _hasError = false;

  final List<String> _pokemonTypes = [
    "Todos",
    "fire",
    "water",
    "grass",
    "electric",
    "psychic",
    "ice",
    "dragon",
    "dark",
    "fairy",
    "normal",
    "fighting",
    "flying",
    "poison",
    "ground",
    "rock",
    "bug",
    "ghost",
    "steel"
  ];

  @override
  void initState() {
    super.initState();
    _loadPokemon();
    _loadFavorites();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_hasMoreData &&
        !_isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePokemon();
    }
  }

  Future<void> _loadPokemon() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final pokemonList = await _pokemonService.fetchPokemon(_currentOffset);
      if (mounted) {
        setState(() {
          _pokemonList.addAll(pokemonList);
          _filteredPokemonList = List.from(_pokemonList);
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        _showErrorSnackBar();
      }
    }
  }

  Future<void> _loadMorePokemon() async {
    if (!_hasMoreData || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final remainingPokemon = PokemonService.totalPokemon - _currentOffset;
      if (remainingPokemon <= 0) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }

      final itemsToLoad = min(PokemonService.pokemonPerPage, remainingPokemon);
      final morePokemon = await _pokemonService.fetchPokemon(_currentOffset);

      if (mounted) {
        setState(() {
          if (morePokemon.isEmpty) {
            _hasMoreData = false;
          } else {
            _pokemonList.addAll(morePokemon);
            _currentOffset += morePokemon.length;

            if (_searchController.text.isEmpty) {
              _filteredPokemonList = List.from(_pokemonList);
              _applyTypeFilter();
              _sortPokemon(_currentSort);
            }
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more Pokemon: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMoreData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar más Pokémon')),
        );
      }
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoritePokemonIds =
          prefs.getStringList('favorites')?.map(int.parse).toSet() ?? {};
    });
  }

  void _filterPokemon(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _filteredPokemonList = List.from(_pokemonList);
        _applyTypeFilter();
        _sortPokemon(_currentSort);
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isLoading = true);

      try {
        final response = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1500&offset=0'),
        );

        if (response.statusCode == 200 && mounted) {
          final data = json.decode(response.body);
          final results = data['results'] as List;

          // Filter Pokemon by query
          final filteredResults = results.where((pokemon) {
            final name = pokemon['name'] as String;
            return name.toLowerCase().contains(query.toLowerCase());
          }).toList();

          final List<Pokemon> searchResults = [];
          for (var pokemon in filteredResults) {
            final id = int.parse(pokemon['url'].toString().split('/')[6]);

            // Check if Pokemon exists in current list
            final existingPokemon = _pokemonList.firstWhere(
              (p) => p.id == id,
              orElse: () => Pokemon(id: -1, name: '', imageUrl: '', type: ''),
            );

            if (existingPokemon.id != -1) {
              searchResults.add(existingPokemon);
              continue;
            }

            // If not found in current list, fetch from API
            try {
              final detailsResponse = await http.get(
                Uri.parse(
                    'https://pokeapi.co/api/v2/pokemon/${pokemon['name']}'),
              );

              if (detailsResponse.statusCode == 200) {
                final detailsData = json.decode(detailsResponse.body);
                searchResults.add(Pokemon(
                  id: id,
                  name: pokemon['name'],
                  imageUrl: detailsData['sprites']['front_default'] ??
                      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
                  type: detailsData['types'][0]['type']['name'],
                ));
              }
            } catch (e) {
              print(
                  'Error fetching details for Pokemon ${pokemon['name']}: $e');
            }
          }

          if (mounted) {
            setState(() {
              _filteredPokemonList = searchResults;
              _applyTypeFilter();
              _sortPokemon(_currentSort);
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        print('Error in search: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al buscar Pokémon')),
          );
        }
      }
    });
  }

  void _applyTypeFilter() {
    if (_selectedType != null && _selectedType != "Todos") {
      _filteredPokemonList = _filteredPokemonList
          .where((p) => p.type.toLowerCase() == _selectedType!.toLowerCase())
          .toList();
    }
  }

  void _filterByType(String? type) {
    setState(() {
      _selectedType = type;
      if (type == "Todos" || type == null) {
        _filteredPokemonList = List.from(_pokemonList); // Create a new list
      } else {
        _filteredPokemonList = _pokemonList
            .where((p) => p.type.toLowerCase() == type.toLowerCase())
            .toList();
      }
      // Apply current sort after filtering
      _sortPokemon(_currentSort);
    });
  }

  void _sortPokemon(SortOrder order) {
    setState(() {
      _currentSort = order;
      switch (order) {
        case SortOrder.numberAsc:
          _filteredPokemonList.sort((a, b) => a.id.compareTo(b.id));
          break;
        case SortOrder.numberDesc:
          _filteredPokemonList.sort((a, b) => b.id.compareTo(a.id));
          break;
        case SortOrder.nameAsc:
          _filteredPokemonList.sort((a, b) => a.name.compareTo(b.name));
          break;
        case SortOrder.nameDesc:
          _filteredPokemonList.sort((a, b) => b.name.compareTo(a.name));
          break;
      }
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filtrar por tipo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _pokemonTypes.map((type) {
                return ListTile(
                  title: Text(type),
                  selected: _selectedType == type,
                  onTap: () {
                    _filterByType(type);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ordenar por'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Número (Ascendente)'),
                selected: _currentSort == SortOrder.numberAsc,
                onTap: () {
                  _sortPokemon(SortOrder.numberAsc);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Número (Descendente)'),
                selected: _currentSort == SortOrder.numberDesc,
                onTap: () {
                  _sortPokemon(SortOrder.numberDesc);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Nombre (A-Z)'),
                selected: _currentSort == SortOrder.nameAsc,
                onTap: () {
                  _sortPokemon(SortOrder.nameAsc);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Nombre (Z-A)'),
                selected: _currentSort == SortOrder.nameDesc,
                onTap: () {
                  _sortPokemon(SortOrder.nameDesc);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Error al cargar los Pokémon. Comprueba tu conexión a internet.'),
        action: SnackBarAction(
          label: 'Reintentar',
          onPressed: _loadPokemon,
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.black : Colors.yellow[100],
      appBar: AppBar(
        backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.amber,
        toolbarHeight: 100, // Increase height to accommodate both rows
        flexibleSpace: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30), // Add padding for status bar
            Text(
              'La Pokédex',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8), // Space between title and buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.casino),
                  tooltip: 'Pokémon Aleatorio',
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    try {
                      final randomPokemon =
                          await _pokemonService.fetchRandomPokemon();
                      if (!mounted) return;

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PokemonDetailsScreen(
                            pokemon: randomPokemon,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al cargar Pokémon aleatorio'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filtrar por tipo',
                  onPressed: _showFilterDialog,
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.sort),
                  tooltip: 'Ordenar',
                  onPressed: _showSortDialog,
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                      widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                  tooltip: 'Cambiar tema',
                  onPressed: widget.toggleTheme,
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  tooltip: 'Favoritos',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FavoritesScreen(allPokemon: _pokemonList),
                      ),
                    );
                  },
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                  tooltip: 'Cambiar vista',
                  onPressed: () {
                    setState(() => _isGridView = !_isGridView);
                  },
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.compare_arrows),
                  tooltip: 'Comparar Pokémon',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PokemonCompareScreen(
                          allPokemon: _pokemonList,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: _hasError
          ? ErrorView(
              message: 'No se han podido cargar los Pokémon',
              details: 'Comprueba tu conexión a internet e inténtalo de nuevo',
              onRetry: _loadPokemon,
            )
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _isLoading
                      ? _buildShimmerEffect()
                      : _isGridView
                          ? _buildGridView()
                          : _buildListView(),
                ),
              ],
            ),
    );
  }

  Widget _buildListView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTabletOrDesktop = constraints.maxWidth > 600;

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: isTabletOrDesktop ? 16.0 : 8.0,
            vertical: 8.0,
          ),
          itemCount: _filteredPokemonList.length + 1,
          itemBuilder: (context, index) {
            if (index == _filteredPokemonList.length) {
              return _isLoadingMore
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: PokemonLoadingAnimation(
                          size: 50.0,
                          color: Colors.red,
                        ),
                      ),
                    )
                  : const SizedBox();
            }

            final pokemon = _filteredPokemonList[index];
            final isFavorite = _favoritePokemonIds.contains(pokemon.id);

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: 1.0,
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Card(
                  color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _getTypeColor(pokemon.type),
                      width: 3.0,
                    ),
                  ),
                  child: ListTile(
                    leading: Hero(
                      tag: 'pokemon-${pokemon.id}',
                      child: Image.network(pokemon.imageUrl,
                          width: 50, height: 50),
                    ),
                    title: Text(
                      "#${pokemon.id} ${pokemon.name.toUpperCase()}",
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                      ),
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
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth > 600 ? 1.3 : 0.8;

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _filteredPokemonList.length + 1,
          itemBuilder: (context, index) {
            if (index == _filteredPokemonList.length) {
              return _isLoadingMore
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: PokemonLoadingAnimation(
                          size: 50.0,
                          color: Colors.red,
                        ),
                      ),
                    )
                  : const SizedBox();
            }

            final pokemon = _filteredPokemonList[index];
            final isFavorite = _favoritePokemonIds.contains(pokemon.id);

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: 1.0,
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Card(
                  color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _getTypeColor(pokemon.type),
                      width: 3.0,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PokemonDetailsScreen(pokemon: pokemon),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'pokemon-${pokemon.id}',
                          child: Image.network(pokemon.imageUrl,
                              width: 80, height: 80),
                        ),
                        Text(
                          "#${pokemon.id} ${pokemon.name.toUpperCase()}",
                          style: TextStyle(
                            color:
                                widget.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : null,
                          ),
                          onPressed: () => _toggleFavorite(pokemon.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerEffect() {
    return const Center(
      child: PokemonLoadingAnimation(
        size: 100.0,
        color: Colors.red,
      ),
    );
  }

  /// ✅ Función para obtener el color del tipo de Pokémon
  Color _getTypeColor(String type) {
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

    return typeColors[type.toLowerCase()] ?? Colors.grey;
  }

  Future<void> _toggleFavorite(int pokemonId) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      if (_favoritePokemonIds.contains(pokemonId)) {
        _favoritePokemonIds.remove(pokemonId);
      } else {
        _favoritePokemonIds.add(pokemonId);
      }
    });

    await prefs.setStringList(
      'favorites',
      _favoritePokemonIds.map((id) => id.toString()).toList(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar Pokémon...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterPokemon('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.white,
        ),
        onChanged: _filterPokemon,
        style: TextStyle(
          color: widget.isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
