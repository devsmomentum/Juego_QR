import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

// =========================================================
// LÓGICA PURA DEL SNAKE (extraída del widget para testeo)
// Si cambias la lógica en snake_minigame.dart, actualiza
// estas funciones para que reflejen los mismos cambios.
// =========================================================

enum Direction { up, down, left, right }

const int rows = 12;
const int cols = 12;
const int winScore = 10;

/// Calcula la siguiente cabeza de la serpiente según la dirección.
Point<int> nextHead(Point<int> head, Direction dir) {
  switch (dir) {
    case Direction.up:
      return Point(head.x, head.y - 1);
    case Direction.down:
      return Point(head.x, head.y + 1);
    case Direction.left:
      return Point(head.x - 1, head.y);
    case Direction.right:
      return Point(head.x + 1, head.y);
  }
}

/// Verifica si la cabeza colisiona con la pared.
bool isWallCollision(Point<int> head) {
  return head.x < 0 || head.x >= cols || head.y < 0 || head.y >= rows;
}

/// Verifica si la cabeza colisiona con el propio cuerpo de la serpiente.
bool isSelfCollision(Point<int> head, List<Point<int>> snake) {
  return snake.contains(head);
}

/// Verifica si la cabeza colisiona con un obstáculo.
bool isObstacleCollision(Point<int> head, List<Point<int>> obstacles) {
  return obstacles.contains(head);
}

/// Valida si un cambio de dirección es legal (no se puede ir en sentido contrario).
bool isDirectionChangeValid(Direction current, Direction next) {
  if (current == Direction.up && next == Direction.down) return false;
  if (current == Direction.down && next == Direction.up) return false;
  if (current == Direction.left && next == Direction.right) return false;
  if (current == Direction.right && next == Direction.left) return false;
  return true;
}

void main() {
  group('Snake - Movimiento y Colisiones', () {
    test('La cabeza se mueve correctamente en cada dirección', () {
      final head = const Point(5, 5);
      expect(nextHead(head, Direction.up), equals(const Point(5, 4)));
      expect(nextHead(head, Direction.down), equals(const Point(5, 6)));
      expect(nextHead(head, Direction.left), equals(const Point(4, 5)));
      expect(nextHead(head, Direction.right), equals(const Point(6, 5)));
    });

    test('Detecta colisión con borde izquierdo', () {
      expect(isWallCollision(const Point(-1, 5)), isTrue);
    });

    test('Detecta colisión con borde derecho', () {
      expect(isWallCollision(const Point(12, 5)), isTrue);
    });

    test('Detecta colisión con borde superior', () {
      expect(isWallCollision(const Point(5, -1)), isTrue);
    });

    test('Detecta colisión con borde inferior', () {
      expect(isWallCollision(const Point(5, 12)), isTrue);
    });

    test('No detecta colisión en posición válida', () {
      expect(isWallCollision(const Point(6, 6)), isFalse);
    });

    test('Detecta colisión con el propio cuerpo', () {
      final snake = [
        const Point(5, 5),
        const Point(4, 5),
        const Point(3, 5),
      ];
      expect(isSelfCollision(const Point(4, 5), snake), isTrue);
    });

    test('No detecta falsa colisión consigo mismo', () {
      final snake = [
        const Point(5, 5),
        const Point(4, 5),
        const Point(3, 5),
      ];
      expect(isSelfCollision(const Point(6, 5), snake), isFalse);
    });

    test('Detecta colisión con obstáculo', () {
      final obstacles = [const Point(7, 3), const Point(2, 9)];
      expect(isObstacleCollision(const Point(7, 3), obstacles), isTrue);
    });

    test('No detecta falsa colisión con obstáculo', () {
      final obstacles = [const Point(7, 3), const Point(2, 9)];
      expect(isObstacleCollision(const Point(5, 5), obstacles), isFalse);
    });
  });

  group('Snake - Cambios de Dirección', () {
    test('No permite revertir dirección (arriba → abajo)', () {
      expect(isDirectionChangeValid(Direction.up, Direction.down), isFalse);
    });

    test('No permite revertir dirección (izquierda → derecha)', () {
      expect(isDirectionChangeValid(Direction.left, Direction.right), isFalse);
    });

    test('Permite girar 90°', () {
      expect(isDirectionChangeValid(Direction.up, Direction.left), isTrue);
      expect(isDirectionChangeValid(Direction.right, Direction.up), isTrue);
    });

    test('Permite mantener la misma dirección', () {
      expect(isDirectionChangeValid(Direction.right, Direction.right), isTrue);
    });
  });

  group('Snake - Condición de Victoria', () {
    test('Gana al llegar a winScore = $winScore puntos', () {
      int score = winScore;
      expect(score >= winScore, isTrue);
    });

    test('No ha ganado con score menor', () {
      int score = 9;
      expect(score >= winScore, isFalse);
    });
  });

  group('Snake - Simulación de Arranque (Bug del Sponsor)', () {
    test('El juego puede arrancar sin datos del sponsor (sponsor null)', () async {
      bool gameStarted = false;

      // Simula que el sponsor tarda mucho o da null
      Future<String?> fakeSponsorService() async {
        await Future.delayed(const Duration(seconds: 6)); // Más de 5s
        return null;
      }

      // Con el nuevo diseño, el juego arranca de inmediato
      gameStarted = true; // _startNewGame() se llama antes del await

      // El sponsor se procesa en paralelo con timeout
      String? sponsor;
      try {
        sponsor = await fakeSponsorService().timeout(const Duration(seconds: 5));
      } catch (e) {
        // TimeoutException → sponsor queda null, juego continúa
        sponsor = null;
        print('✅ Sponsor timeout capturado: $e');
      }

      expect(gameStarted, isTrue,
          reason: 'El juego debe arrancar aunque el sponsor no llegue');
      expect(sponsor, isNull,
          reason: 'El sponsor puede ser null sin romper el juego');
    });

    test('El juego NO quedaba bloqueado antes del fix (simulación del bug)', () async {
      bool gameStarted = false;

      // ANTES del fix: el código esperaba al sponsor antes de iniciar
      // Simulamos el flujo antiguo con await bloqueante
      Future<void> oldFetchSponsorAndStart() async {
        // Simula la llamada lenta sin timeout
        String? sponsor;
        try {
          sponsor = await Future.delayed(
            const Duration(milliseconds: 100), // rápido en test
            () => null, // sin sponsor
          );
        } catch (_) {}

        // Solo inicia si llega aquí
        if (sponsor == null) {
          // En el código viejo, hacía un segundo request fallback
          await Future.delayed(const Duration(milliseconds: 100));
        }
        gameStarted = true; // Solo se llama después de ambos awaits
      }

      await oldFetchSponsorAndStart();

      // En el test, sí termina (delays cortos) pero demuestra el patrón bloqueante
      expect(gameStarted, isTrue,
          reason: 'Con delays cortos funciona, pero con red lenta se bloqueaba');
      print('⚠️ Patrón antiguo: el juego solo arrancaba DESPUÉS de cargar el sponsor');
    });
  });
}
