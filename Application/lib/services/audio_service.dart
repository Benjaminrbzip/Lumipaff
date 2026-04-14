import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal() {
    // Initialisation Audioplayers
    _musicPlayer.setReleaseMode(ap.ReleaseMode.loop);
    _musicPlayer.setVolume(_musicVolume);
    _sfxPlayer.setVolume(_sfxVolume);

    // Initialisation Just Audio (Simon)
    _initSimonPlayer();
  }

  final ap.AudioPlayer _sfxPlayer = ap.AudioPlayer();
  final ap.AudioPlayer _musicPlayer = ap.AudioPlayer();
  final AudioPlayer _simonPlayer = AudioPlayer();

  double _sfxVolume = 0.8;
  double _musicVolume = 0.3;

  double get sfxVolume => _sfxVolume;
  double get musicVolume => _musicVolume;

  // Mapping des pitches pour le Simon (Pod 1 à 9)
  final List<double> _simonPitches = [
    1.0,  // Pod 1 (Do)
    1.12, // Pod 2 (Ré)
    1.26, // Pod 3 (Mi)
    1.33, // Pod 4 (Fa)
    1.50, // Pod 5 (Sol)
    1.68, // Pod 6 (La)
    1.89, // Pod 7 (Si)
    2.0,  // Pod 8 (Do aigu)
    2.24, // Pod 9 (Ré aigu)
  ];

  Future<void> _initSimonPlayer() async {
    try {
      await _simonPlayer.setAsset('assets/audio/SFX/simon-sound.wav');
    } catch (e) {
      print("Erreur initialisation Simon Player : $e");
    }
  }

  /// Joue un son court (SFX) depuis les assets
  Future<void> playSfx(String assetPath) async {
    try {
      await _sfxPlayer.play(ap.AssetSource(assetPath), volume: _sfxVolume);
    } catch (e) {
      print("Erreur de lecture SFX : $e");
    }
  }

  /// Joue la note du Simon avec le pitch spécifique au pod
  Future<void> playSimonNote(int podIndex) async {
    if (podIndex < 0 || podIndex >= _simonPitches.length) return;
    
    try {
      double pitch = _simonPitches[podIndex];
      // just_audio : setSpeed change la vitesse ET le pitch (comportement vinyle/bande)
      await _simonPlayer.setSpeed(pitch);
      await _simonPlayer.setVolume(_sfxVolume);
      await _simonPlayer.seek(Duration.zero);
      await _simonPlayer.play();
    } catch (e) {
      print("Erreur lecture note Simon : $e");
    }
  }

  /// Lance la musique de fond (loop)
  Future<void> startMusic(String assetPath) async {
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.play(ap.AssetSource(assetPath));
    } catch (e) {
      print("Erreur de lecture Musique : $e");
    }
  }

  Future<void> pauseMusic() async {
    await _musicPlayer.pause();
  }

  Future<void> resumeMusic() async {
    await _musicPlayer.resume();
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  /// Définit le volume de la musique
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume;
    await _musicPlayer.setVolume(_musicVolume);
  }

  /// Définit le volume des SFX
  void setSfxVolume(double volume) {
    _sfxVolume = volume;
  }

  void dispose() {
    _sfxPlayer.dispose();
    _musicPlayer.dispose();
    _simonPlayer.dispose();
  }
}
