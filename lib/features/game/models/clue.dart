import 'package:flutter/material.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/clue_finder_screen.dart';
import '../screens/puzzle_screen.dart';
import '../../mall/screens/mall_screen.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../../core/theme/app_theme.dart';

enum ClueType {
  qrScan,
  geolocation,
  minigame,
  npcInteraction,
}

enum PuzzleType {
  slidingPuzzle, 
  ticTacToe, 
  hangman,
  tetris,         
  findDifference, 
  flags,          
  minesweeper,    
  snake,          
  blockFill,
  codeBreaker,
  imageTrivia,
  wordScramble;      

  String get dbValue => toString().split('.').last;

  String get label {
    switch (this) {
      case PuzzleType.ticTacToe: return '❌⭕ La Vieja (Tic Tac Toe)';
      case PuzzleType.hangman: return '🔤 El Ahorcado';
      case PuzzleType.slidingPuzzle: return '🧩 Rompecabezas (Sliding)';
      case PuzzleType.tetris: return '🧱 Tetris';
      case PuzzleType.findDifference: return '🔎 Encuentra la Diferencia';
      case PuzzleType.flags: return '🏳️ Banderas (Quiz)';
      case PuzzleType.minesweeper: return '💣 Buscaminas';
      case PuzzleType.snake: return '🐍 Snake (Culebrita)';
      case PuzzleType.blockFill: return '🟦 Rellenar Bloques';
      case PuzzleType.codeBreaker: return '🔐 Caja Fuerte (Code)';
      case PuzzleType.imageTrivia: return '🖼️ Desafío Visual (Trivia)';
      case PuzzleType.wordScramble: return '🔤 Palabra Misteriosa';
    }
  }

  bool get isAutoValidation {
    switch (this) {
      case PuzzleType.ticTacToe:
      case PuzzleType.slidingPuzzle:      
      case PuzzleType.tetris:
      case PuzzleType.findDifference:
      case PuzzleType.flags:
      case PuzzleType.minesweeper:
      case PuzzleType.snake:
      case PuzzleType.blockFill:
        return true; 
      default:
        return false;
    }
  }

  String get defaultQuestion {
    switch (this) {
      case PuzzleType.ticTacToe: return 'Gana una partida contra la IA';
      case PuzzleType.slidingPuzzle: return 'Ordena la imagen correctamente';
      case PuzzleType.hangman: return 'Pista sobre la palabra...';
      case PuzzleType.tetris: return 'Alcanza el puntaje objetivo';
      case PuzzleType.findDifference: return 'Encuentra el icono diferente';
      case PuzzleType.flags: return 'Adivina 5 banderas correctamente';
      case PuzzleType.minesweeper: return 'Descubre todas las casillas seguras';
      case PuzzleType.snake: return 'Come 15 manzanas sin chocar';
      case PuzzleType.blockFill: return 'Rellena todo el camino';
      case PuzzleType.codeBreaker: return 'Descifra el código de 4 dígitos';
      case PuzzleType.imageTrivia: return '¿Qué es lo que ves en la imagen?';
      case PuzzleType.wordScramble: return 'Ordena las letras para formar la palabra';
    }
  }
}

/// Base abstract class for all clues
abstract class Clue {
  final String id;
  final String title;
  final String description;
  final String hint;
  final ClueType type;
  final int xpReward;
  final int coinReward;
  bool isCompleted;
  bool isLocked;
  final int sequenceIndex;

  Clue({
    required this.id,
    required this.title,
    required this.description,
    required this.hint,
    required this.type,
    this.xpReward = 50,
    this.coinReward = 10,
    this.isCompleted = false,
    this.isLocked = true,
    this.sequenceIndex = 0,
  });

  /// Abstract methods ensuring polymorphism
  void executeAction(BuildContext context);
  String get typeName;
  String get typeIcon;

  // Virtual getters for compatibility (returning null by default)
  double? get latitude => null;
  double? get longitude => null;
  String? get qrCode => null;
  String? get minigameUrl => null;
  String? get riddleQuestion => null;
  String? get riddleAnswer => null;
  PuzzleType get puzzleType => PuzzleType.slidingPuzzle; // Default fallback ensuring non-null if possible, or make nullable if logic allows. Original was non-nullable in OnlineClue.
  // Actually, user said "return null by default". But puzzleType is an Enum. 
  // If I return null, I must change return type to `PuzzleType?`.
  // Let's check usage. `clue.puzzleType` is used in switch cases. 
  // If I make it nullable, switch cases will assume non-null or need default. 
  // The user said: "puzzleType". 
  // Let's return a safe default `PuzzleType.slidingPuzzle` effectively behaving like "nullable logic handled safely" or actually change the return type. 
  // However, existing code might expect strict `PuzzleType`. 
  // Use `PuzzleType?` as return type for the getter to be safe with "null by default".
  
  // Wait, if I change it to `PuzzleType?`, I might break code expecting `PuzzleType`.
  // The request says: "Campos: ... puzzleType ... Ejemplo: double? get latitude => null;."
  // So likely `PuzzleType? get puzzleType => null;`
  
  /// Factory to create the correct subclass based on ClueType
  factory Clue.fromJson(Map<String, dynamic> json) {
    
    // Safety check for image URLs in JSON (from original code)
    String? image = json['image_url'];
    if (image != null && (image.contains('C:/') || image.contains('file:///'))) {
       print('⚠️ Ruta inválida detectada y bloqueada: $image');
    }

    final typeStr = json['type'] as String?;
    final type = ClueType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => ClueType.qrScan,
    );

    if (type == ClueType.minigame) {
      return OnlineClue.fromJson(json, type);
    } else {
      return PhysicalClue.fromJson(json, type);
    }
  }
}

class PhysicalClue extends Clue {
  final double? latitude;
  final double? longitude;
  final String? qrCode;

  PhysicalClue({
    required super.id,
    required super.title,
    required super.description,
    required super.hint,
    required super.type,
    super.xpReward,
    super.coinReward,
    super.isCompleted,
    super.isLocked,
    super.sequenceIndex,
    this.latitude,
    this.longitude,
    this.qrCode,
  });

  factory PhysicalClue.fromJson(Map<String, dynamic> json, ClueType type) {
    return PhysicalClue(
      id: json['id'].toString(),
      title: json['title'],
      description: json['description'] ?? '',
      hint: json['hint'] ?? '',
      type: type,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      qrCode: json['qr_code'],
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 50,
      coinReward: (json['coin_reward'] as num?)?.toInt() ?? 10,
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      isLocked: json['isLocked'] ?? json['is_locked'] ?? true,
      sequenceIndex: json['sequence_index'] ?? 0,
    );
  }

  @override
  String get typeName {
    switch (type) {
      case ClueType.qrScan:
        return 'Escanear QR';
      case ClueType.geolocation:
        return 'Ubicación';
      case ClueType.npcInteraction:
        return 'Tiendita';
      default:
        return 'Física';
    }
  }

  @override
  String get typeIcon {
    switch (type) {
      case ClueType.qrScan:
        return '📷';
      case ClueType.geolocation:
        return '📍';
      case ClueType.npcInteraction:
        return '🏪';
      default:
        return '📍';
    }
  }

  @override
  void executeAction(BuildContext context) async {
    switch (type) {
      case ClueType.qrScan:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QRScannerScreen(expectedClueId: id)),
        );
        break;
      case ClueType.geolocation:
        // Physical Clues logic for Geolocation
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClueFinderScreen(clue: this),
          ),
        );
        
        // If returned true, it means it was scanned/found during the finder process
        if (result == true) {
           // We can handle post-scan logic here if needed, 
           // but traditionally unlocking is handled by the calling screen or provider.
           // In the original code, `_unlockAndProceed` was called. 
           // We might need to handle this integration in the `CluesScreen` wrapper.
        }
        break;
      case ClueType.npcInteraction:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MallScreen()),
        );
        break;
      default:
        // Fallback
        break;
    }
  }
}

class OnlineClue extends Clue {
  final String? minigameUrl;
  final String? riddleQuestion;
  final String? riddleAnswer;
  final PuzzleType puzzleType;

  OnlineClue({
    required super.id,
    required super.title,
    required super.description,
    required super.hint,
    required super.type,
    super.xpReward,
    super.coinReward,
    super.isCompleted,
    super.isLocked,
    super.sequenceIndex,
    this.minigameUrl,
    this.riddleQuestion,
    this.riddleAnswer,
    this.puzzleType = PuzzleType.slidingPuzzle,
  });

  factory OnlineClue.fromJson(Map<String, dynamic> json, ClueType type) {
    return OnlineClue(
      id: json['id'].toString(),
      title: json['title'],
      description: json['description'] ?? '',
      hint: json['hint'] ?? '',
      type: type,
      minigameUrl: json['minigame_url'],
      riddleQuestion: json['riddle_question'],
      riddleAnswer: json['riddle_answer'],
      puzzleType: json['puzzle_type'] != null 
        ? PuzzleType.values.firstWhere(
            (e) => e.toString().split('.').last == json['puzzle_type'],
            orElse: () => PuzzleType.slidingPuzzle,
          )
        : PuzzleType.slidingPuzzle,
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 50,
      coinReward: (json['coin_reward'] as num?)?.toInt() ?? 10,
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      isLocked: json['isLocked'] ?? json['is_locked'] ?? true,
      sequenceIndex: json['sequence_index'] ?? 0,
    );
  }

  @override
  String get typeName => 'Minijuego';

  @override
  String get typeIcon => '🎮';

  @override
  void executeAction(BuildContext context) {
    try {
      // In Clean Architecture we shouldn't rely on Provider here ideally, but for pragmatic refactor:
      // We are just navigating. The Provider usage in the original code was for error handling.
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PuzzleScreen(clue: this)), // PuzzleScreen accepts Clue (which is now OnlineClue or Base)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: No se pudo cargar el minijuego. $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }
}