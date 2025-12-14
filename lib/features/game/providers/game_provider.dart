import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clue.dart';
import '../../../shared/models/player.dart';

class GameProvider extends ChangeNotifier {
  List<Clue> _clues = [];
  List<Player> _leaderboard = [];
  int _currentClueIndex = 0;
  bool _isGameActive = false;
  bool _isLoading = false;
  String? _currentEventId;
  String? _errorMessage;
  
  final _supabase = Supabase.instance.client;
  
  List<Clue> get clues => _clues;
  List<Player> get leaderboard => _leaderboard;
  Clue? get currentClue => _currentClueIndex < _clues.length ? _clues[_currentClueIndex] : null;
  
  // Getter que faltaba para el Mini Mapa
  int get currentClueIndex => _currentClueIndex;
  
  bool get isGameActive => _isGameActive;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get completedClues => _clues.where((c) => c.isCompleted).length;
  int get totalClues => _clues.length;
  String? get currentEventId => _currentEventId;
  
  GameProvider() {
    // _initializeMockData(); // Removed mock data
  }
  
  Future<void> fetchClues({String? eventId}) async {
    if (eventId != null) {
      _currentEventId = eventId;
    }
    
    final idToUse = eventId ?? _currentEventId;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      if (idToUse == null) {
         debugPrint('Warning: fetchClues called without eventId');
         _isLoading = false;
         notifyListeners();
         return;
      }

      final response = await _supabase.functions.invoke(
        'game-play/get-clues', 
        body: {'eventId': idToUse},
        method: HttpMethod.post,
      );
      
      if (response.status == 200) {
        final List<dynamic> data = response.data;
        _clues = data.map((json) => Clue.fromJson(json)).toList();
        
        // Debug logs to verify clue status
        for (var c in _clues) {
          debugPrint('Clue ${c.title} (ID: ${c.id}): locked=${c.isLocked}, completed=${c.isCompleted}');
        }
        
        // --- DEMO: Inject Tic Tac Toe Clue (First - UNLOCKED) ---
        _clues.insert(0, Clue(
          id: 'demo_tictactoe',
          title: 'La Vieja (Tic Tac Toe)',
          description: 'Gana una partida contra la IA para avanzar.',
          hint: 'Coloca 3 fichas en línea antes que la IA.',
          type: ClueType.minigame,
          puzzleType: PuzzleType.ticTacToe,
          xpReward: 200,
          coinReward: 50,
          isLocked: false,
          isCompleted: false,
        ));

        // --- DEMO: Inject Hangman Clue (Second - LOCKED) ---
        _clues.insert(1, Clue(
          id: 'demo_hangman',
          title: 'El Ahorcado',
          description: 'Adivina la palabra antes de que te ahorquen.',
          hint: 'Ve a la Cafetería y escanea el código QR en la caja.',
          riddleQuestion: 'Framework de Google', // Pista del juego
          riddleAnswer: 'FLUTTER',
          type: ClueType.minigame,
          puzzleType: PuzzleType.hangman,
          xpReward: 150,
          coinReward: 40,
          isLocked: true,
          isCompleted: false,
        ));
        
        // --- DEMO: Inject Sliding Puzzle Clue (Third - LOCKED) ---
        _clues.insert(2, Clue(
          id: 'demo_puzzle_sliding',
          title: 'Rompecabezas Sliding',
          description: 'Ordena las piezas para resolver el acertijo.',
          hint: 'Dirígete al Laboratorio de Computación y busca el código cerca de la impresora.',
          type: ClueType.minigame,
          puzzleType: PuzzleType.slidingPuzzle,
          xpReward: 150,
          coinReward: 100,
          isLocked: true,
          isCompleted: false,
        ));
        // ---------------------------------------------
        
        // Find first unlocked but not completed clue to set as current
        final index = _clues.indexWhere((c) => !c.isCompleted && !c.isLocked);
        if (index != -1) {
          _currentClueIndex = index;
        } else {
          // If all are completed, set index to length (end of list)
          _currentClueIndex = _clues.length;
        }
      } else {
        _errorMessage = 'Error fetching clues: ${response.status}';
        debugPrint('Error fetching clues: ${response.status} ${response.data}');
      }
    } catch (e) {
      _errorMessage = 'Error fetching clues: $e';
      debugPrint('Error fetching clues: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> startGame(String eventId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _supabase.functions.invoke('game-play/start-game', 
        body: {'eventId': eventId},
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        _isGameActive = true;
        await fetchClues(eventId: eventId);
      } else {
        debugPrint('Error starting game: ${response.status} ${response.data}');
      }
    } catch (e) {
      debugPrint('Error starting game: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void unlockClue(String clueId) {
    final index = _clues.indexWhere((c) => c.id == clueId);
    if (index != -1) {
      _clues[index].isLocked = false;
      _currentClueIndex = index; // Move to this clue
      notifyListeners();
    }
  }

  void completeLocalClue(String clueId) {
    final index = _clues.indexWhere((c) => c.id == clueId);
    if (index != -1) {
      _clues[index].isCompleted = true;
      // Note: We do NOT auto-unlock the next clue here. 
      // The user must scan a QR code to call unlockClue() for the next one.
      notifyListeners();
    }
  }

  Future<bool> completeCurrentClue(String answer, {String? clueId}) async {
    
    String targetId;

    // Lógica para determinar qué ID usar
    if (clueId != null) {
      targetId = clueId;
    } else {
      // Si no nos pasan ID, usamos el índice interno (comportamiento original)
      if (_currentClueIndex >= _clues.length) return false;
      targetId = _clues[_currentClueIndex].id;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _supabase.functions.invoke('game-play/complete-clue', 
        body: {
          'clueId': targetId, // <--- Usamos el ID correcto
          'answer': answer,
        },
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        await fetchClues(); 
        return true;
      } else {
        debugPrint('Error completing clue: ${response.status} ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('Error completing clue: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> skipCurrentClue() async {
    if (_currentClueIndex >= _clues.length) return false;
    
    final clue = _clues[_currentClueIndex];
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _supabase.functions.invoke('game-play/skip-clue', 
        body: {
          'clueId': clue.id,
        },
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        await fetchClues();
        return true;
      } else {
        debugPrint('Error skipping clue: ${response.status} ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('Error skipping clue: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void switchToClue(String clueId) {
    final index = _clues.indexWhere((c) => c.id == clueId);
    if (index != -1 && !_clues[index].isLocked) {
      _currentClueIndex = index;
      notifyListeners();
    }
  }
  
  Future<void> fetchLeaderboard() async {
    // Necesitamos un evento activo para filtrar
    if (_currentEventId == null) return;

    try {
      final response = await _supabase.functions.invoke(
        'game-play/get-leaderboard',
        body: {'eventId': _currentEventId},
        method: HttpMethod.post,
      );

      if (response.status == 200) {
        final List<dynamic> data = response.data;
        _leaderboard = data.map((json) => Player.fromJson(json)).toList();
        notifyListeners();
      } else {
        debugPrint('Error fetching leaderboard: ${response.status} ${response.data}');
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }
  }
  
  void updateLeaderboard(Player player) {
    // Deprecated
  }
}
