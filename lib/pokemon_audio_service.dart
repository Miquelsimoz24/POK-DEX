import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PokemonAudioService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> playPokemonCry(int pokemonId) async {
    try {
      // Get the Pokemon details from the API to get the cry URL
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final cries = data['cries'];

        // Get the latest cry version available
        final String? cryUrl = cries?['latest'] ??
            cries?['legacy'] ??
            'https://play.pokemonshowdown.com/audio/cries/$pokemonId.mp3';

        if (cryUrl != null) {
          print('Playing Pokemon cry from: $cryUrl');

          await _audioPlayer.stop();
          await _audioPlayer.setSourceUrl(cryUrl);
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      print('Error playing Pokemon cry: $e');
    }
  }

  static void dispose() {
    _audioPlayer.dispose();
  }
}
