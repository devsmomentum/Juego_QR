import 'package:flutter/material.dart';
import '../../models/clue.dart';
import '../../../../core/theme/app_theme.dart';

/// Widget de minijuego para ordenar letras desordenadas y formar la palabra correcta.
/// 
/// Recibe una [clue] que contiene la respuesta a formar y un callback [onSuccess]
/// que se ejecuta cuando el jugador completa el desafío correctamente.
class WordScrambleWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const WordScrambleWidget({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<WordScrambleWidget> createState() => _WordScrambleWidgetState();
}

class _WordScrambleWidgetState extends State<WordScrambleWidget> {
  late List<String> _shuffledLetters;
  String _currentWord = "";

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    final answer = widget.clue.riddleAnswer?.toUpperCase() ?? "TREASURE";
    _shuffledLetters = answer.split('')..shuffle();
    _currentWord = "";
  }

  void _onLetterTap(String letter) {
    setState(() {
      _currentWord += letter;
      _shuffledLetters.remove(letter);
    });
  }

  void _onReset() {
    setState(() {
      _initializeGame();
    });
  }

  void _checkAnswer() {
    if (_currentWord == widget.clue.riddleAnswer?.toUpperCase()) {
      // ÉXITO: Llamar callback
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Incorrecto'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      _onReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final answerLength = widget.clue.riddleAnswer?.length ?? 8;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.shuffle, size: 40, color: AppTheme.secondaryPink),
          const SizedBox(height: 8),
          const Text(
            'PALABRA MISTERIOSA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          
          // Display de la palabra actual
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentGold, width: 2),
            ),
            child: Text(
              _currentWord
                  .padRight(answerLength, '_')
                  .split('')
                  .join(' '),
              style: const TextStyle(
                color: AppTheme.accentGold,
                fontSize: 20,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Letras disponibles
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _shuffledLetters
                .map((letter) => GestureDetector(
                      onTap: () => _onLetterTap(letter),
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryPurple,
                              AppTheme.secondaryPink,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onReset,
                  child: const Text("Reiniciar"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _currentWord.length == answerLength
                      ? _checkAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                  ),
                  child: const Text("COMPROBAR"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
