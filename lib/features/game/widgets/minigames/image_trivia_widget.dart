import 'package:flutter/material.dart';
import '../../models/clue.dart';
import '../../../../core/theme/app_theme.dart';

/// Widget de minijuego de trivia visual donde el usuario debe identificar
/// lo que muestra una imagen y escribir la respuesta correcta.
/// 
/// Recibe una [clue] que contiene la URL de la imagen, la pregunta y la respuesta,
/// más un callback [onSuccess] que se ejecuta cuando el jugador acierta.
class ImageTriviaWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const ImageTriviaWidget({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<ImageTriviaWidget> createState() => _ImageTriviaWidgetState();
}

class _ImageTriviaWidgetState extends State<ImageTriviaWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _showHint = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    final userAnswer = _controller.text.trim().toLowerCase();
    final correctAnswer = widget.clue.riddleAnswer?.trim().toLowerCase() ?? "";
    
    if (userAnswer == correctAnswer ||
        (correctAnswer.isNotEmpty &&
            userAnswer.contains(correctAnswer.split(' ').first))) {
      // ÉXITO: Llamar callback
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Incorrecto'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(
            Icons.image_outlined,
            size: 35,
            color: AppTheme.secondaryPink,
          ),
          const SizedBox(height: 8),
          const Text(
            'DESAFÍO VISUAL',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          
          // Imagen del desafío
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                  blurRadius: 15,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.clue.minigameUrl ?? 'https://via.placeholder.com/400',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  height: 180,
                  color: AppTheme.cardBg,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.white38),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          
          // Pregunta
          Text(
            widget.clue.riddleQuestion ?? "¿Qué es esto?",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Campo de respuesta
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Tu respuesta...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Pista (si está visible)
          if (_showHint)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.accentGold),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.clue.hint,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showHint = !_showHint),
                  child: Text(_showHint ? "Ocultar" : "Pista"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _checkAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                  ),
                  child: const Text("VERIFICAR"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
