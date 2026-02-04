import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MusicProvider with ChangeNotifier {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isMuted = false;
  final String _assetPath = 'audio/background_music.mp3';

  MusicProvider() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _configureAudio();
  }

  Future<void> _configureAudio() async {
    if (kIsWeb) return;
    
    try {
      // Configuración para permitir que la música suene de fondo sin interrupciones
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none, // No pide foco exclusivo, ideal para música de fondo
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));
    } catch (e) {
      debugPrint('MusicProvider Context Error: $e');
    }
  }

  bool get isPlaying => _isPlaying;

  Future<void> startMusic() async {
    // No reproducir música en Web (Admin) por petición del usuario
    if (kIsWeb) return;
    
    // Si ya está sonando, no hacemos nada para evitar cortes
    if (_isPlaying) {
      // Por si acaso se pausó, intentamos reanudar
      _audioPlayer.resume();
      return;
    }

    try {
      debugPrint('MusicProvider: Iniciando música $_assetPath');
      await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
      
      // Iniciar reproducción desde el asset
      await _audioPlayer.play(AssetSource(_assetPath));
      _isPlaying = true;
      notifyListeners();
      debugPrint('MusicProvider: Reproducción iniciada con éxito');
    } catch (e) {
      debugPrint('MusicProvider Error: $e');
      // Intento con ruta directa si falla el AssetSource estándar
      try {
        await _audioPlayer.play(AssetSource('audio/background_music.mp3'));
        _isPlaying = true;
        notifyListeners();
      } catch (e2) {
        debugPrint('MusicProvider Critical Error: $e2');
      }
    }
  }

  Future<void> stopMusic() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('MusicProvider Stop Error: $e');
    }
  }

  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
      notifyListeners();
    } catch (e) {
      debugPrint('MusicProvider Mute Error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
