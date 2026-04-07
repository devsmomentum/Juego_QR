import 'dart:async';
import 'package:flutter/material.dart';
import '../models/clue.dart';
import '../models/scenario.dart';
import '../../../shared/models/player.dart';

enum TutorialStage {
  scenarioSelection,
  welcome,
  clueView,
  scanning,
  minigame,
  results,
  powers,
  finished
}

class TutorialStateProvider extends ChangeNotifier {
  TutorialStage _currentStage = TutorialStage.scenarioSelection;
  TutorialStage get currentStage => _currentStage;

  int _currentClueIndex = 0;
  int get currentClueIndex => _currentClueIndex;

  bool _isFrozen = false;
  bool get isFrozen => _isFrozen;

  bool _hasShield = false;
  bool get hasShield => _hasShield;

  bool _isShieldActive = false;
  bool get isShieldActive => _isShieldActive;

  // Mock Data
  final List<Clue> mockClues = [
    PhysicalClue(
      id: 'tut_1',
      title: 'El Inicio del Hacker',
      hint: 'Busca el nodo central donde la red respira. El código está en la entrada.',
      type: ClueType.qrScan,
      xpReward: 50,
      sequenceIndex: 1,
    ),
  ];

  final List<Player> mockLeaderboard = [
    Player(userId: 'bot_1', name: 'Cyber_Rex', email: '', completedCluesCount: 1, totalXP: 150, avatarId: 'bot_1'),
    Player(userId: 'bot_2', name: 'Neon_Ghost', email: '', completedCluesCount: 0, totalXP: 80, avatarId: 'bot_2'),
    Player(userId: 'player_id', name: 'Tú (Recluta)', email: '', completedCluesCount: 0, totalXP: 0, avatarId: 'player'),
  ];

  final mockScenario = const Scenario(
    id: 'tut_scenario',
    name: 'Misión de Iniciación',
    description: 'Aprende los fundamentos de la red y el espionaje corporativo en este tutorial guiado.',
    location: 'Santuario Digital',
    imageUrl: 'assets/images/mision_iniciacion.jpg',
    state: 'Active',
    maxPlayers: 100,
    starterClue: 'tut_1',
    secretCode: 'TUTORIAL123',
    status: 'active',
  );

  void setStage(TutorialStage stage) {
    _currentStage = stage;
    notifyListeners();
  }

  void nextStage() {
    final nextIndex = _currentStage.index + 1;
    if (nextIndex < TutorialStage.values.length) {
      _currentStage = TutorialStage.values[nextIndex];
      notifyListeners();
    }
  }

  void simulateProgression() {
    // Simular que el jugador gana puntos
    final player = mockLeaderboard.firstWhere((p) => p.userId == 'player_id');
    player.completedCluesCount++;
    player.addExperience(100);
    
    // Reordenar ranking
    mockLeaderboard.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    notifyListeners();
  }

  void simulateIncomingSabotage() {
    if (_isShieldActive) {
      _isShieldActive = false; // El escudo se consume bloqueando el ataque
      notifyListeners();
      return;
    }
    
    _isFrozen = true;
    notifyListeners();
    
    Timer(const Duration(seconds: 5), () {
      _isFrozen = false;
      notifyListeners();
    });
  }

  void giveShield() {
    _hasShield = true;
    notifyListeners();
  }

  void useShield() {
    _hasShield = false;
    _isShieldActive = true;
    notifyListeners();
  }

  Clue get currentClue => mockClues[_currentClueIndex];
}
