import 'package:flutter/material.dart';
import '../../../game/widgets/minigames/drink_mixer_minigame.dart';
import '../../../game/models/clue.dart';

class DrinkMixerConfigScreen extends StatefulWidget {
  const DrinkMixerConfigScreen({super.key});

  @override
  State<DrinkMixerConfigScreen> createState() => _DrinkMixerConfigScreenState();
}

class _DrinkMixerConfigScreenState extends State<DrinkMixerConfigScreen> {
  // Configuración del minijuego
  double _timeLimit = 90.0;

  void _testMinigame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DrinkMixerMinigame(
          clue: OnlineClue(
            id: 'test-mixer',
            title: 'Neon Mixology Test',
            description: 'Mezcla los colores neón para igualar el cóctel objetivo.',
            hint: 'Prueba mezclando rojo y azul para obtener morado.',
            type: ClueType.minigame,
            puzzleType: PuzzleType.drinkMixer,
          ),
          onSuccess: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('¡Mezcla perfecta! Cliente satisfecho.')),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Cócteles de Neón'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajustes del Minijuego',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Tiempo Limite
            Text('Tiempo Límite: ${_timeLimit.toInt()} segundos'),
            Slider(
              value: _timeLimit,
              min: 30,
              max: 180,
              divisions: 15,
              label: '${_timeLimit.toInt()}s',
              onChanged: (value) {
                setState(() {
                  _timeLimit = value;
                });
              },
            ),

            const SizedBox(height: 40),

            Center(
              child: ElevatedButton.icon(
                onPressed: _testMinigame,
                icon: const Icon(Icons.local_bar),
                label: const Text('PROBAR MEZCLADOR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            const Card(
              color: Colors.white10,
              child: Padding(
                padding: EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueAccent),
                    SizedBox(height: 10),
                    Text(
                      'Este minijuego desafía al jugador a mezclar colores primarios (Rojo, Azul, Amarillo) para igualar un cóctel objetivo generado aleatoriamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
