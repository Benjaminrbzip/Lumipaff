import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();

  /// Joue un son court (SFX) depuis les assets
  Future<void> playSfx(String assetPath) async {
    try {
      await _sfxPlayer.stop(); // Arrête le son précédent si nécessaire
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print("Erreur de lecture audio : $e");
    }
  }

  /// Préchauffe les sons si nécessaire (optionnel)
  void dispose() {
    _sfxPlayer.dispose();
  }
}
