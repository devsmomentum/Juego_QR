import 'package:flutter_test/flutter_test.dart';

// Definición mínima necesaria para testear la lógica sin depender de Flutter UI
bool checkWin(List<String> board, String player) {
  // Rows
  for (int i = 0; i < 9; i += 3) {
    if (board[i] == player &&
        board[i + 1] == player &&
        board[i + 2] == player) return true;
  }
  // Cols
  for (int i = 0; i < 3; i++) {
    if (board[i] == player &&
        board[i + 3] == player &&
        board[i + 6] == player) return true;
  }
  // Diagonals
  if (board[0] == player && board[4] == player && board[8] == player)
    return true;
  if (board[2] == player && board[4] == player && board[6] == player)
    return true;

  return false;
}

void main() {
  group('TicTacToe Win Logic Tests', () {
    test('Row win detection', () {
      final board = ['X', 'X', 'X', '', '', '', '', '', ''];
      expect(checkWin(board, 'X'), isTrue);
    });

    test('Column win detection', () {
      final board = ['O', '', '', 'O', '', '', 'O', '', ''];
      expect(checkWin(board, 'O'), isTrue);
    });

    test('Diagonal win detection (TL-BR)', () {
      final board = ['X', '', '', '', 'X', '', '', '', 'X'];
      expect(checkWin(board, 'X'), isTrue);
    });

    test('Diagonal win detection (TR-BL)', () {
      final board = ['', '', 'O', '', 'O', '', 'O', '', ''];
      expect(checkWin(board, 'O'), isTrue);
    });

    test('No win detection', () {
      final board = ['X', 'O', 'X', 'X', 'O', 'O', 'O', 'X', 'X'];
      expect(checkWin(board, 'X'), isFalse);
      expect(checkWin(board, 'O'), isFalse);
    });
    
    test('Screenshot 2 Case (Diagonal 0, 4, 8)', () {
      // Row 1: X (0), ? (1), O (2)
      // Row 2: O (3), X (4), ? (5)
      // Row 3: X (6), ? (7), X (8)
      final board = ['X', '', 'O', 'O', 'X', '', 'X', '', 'X'];
      expect(checkWin(board, 'X'), isTrue);
    });
  });
}
