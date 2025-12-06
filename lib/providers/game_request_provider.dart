import 'package:flutter/material.dart';
import '../models/game_request.dart';
import '../models/player.dart';

class GameRequestProvider extends ChangeNotifier {
  final List<GameRequest> _requests = [];

  List<GameRequest> get requests => _requests;

  void submitRequest(Player player) {
    // Check if request already exists
    if (_requests.any((r) => r.playerId == player.id)) {
      return;
    }

    final newRequest = GameRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      playerId: player.id,
      status: 'pending',
    );
    
    _requests.add(newRequest);
    notifyListeners();
  }

  GameRequest? getRequestForPlayer(String playerId) {
    try {
      return _requests.firstWhere((r) => r.playerId == playerId);
    } catch (e) {
      return null;
    }
  }

  void approveRequest(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final oldRequest = _requests[index];
      _requests[index] = GameRequest(
        id: oldRequest.id,
        playerId: oldRequest.playerId,
        status: 'approved',
      );
      notifyListeners();
    }
  }
  
  void rejectRequest(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final oldRequest = _requests[index];
      _requests[index] = GameRequest(
        id: oldRequest.id,
        playerId: oldRequest.playerId,
        status: 'rejected',
      );
      notifyListeners();
    }
  }
}
