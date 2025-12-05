import 'package:flutter/material.dart';
import '../models/game_request.dart';
import '../models/player.dart';

class GameRequestProvider extends ChangeNotifier {
  final List<GameRequest> _requests = [];

  void submitRequest(Player player) {
    // TODO: Implement submit logic
    notifyListeners();
  }

  GameRequest? getRequestForPlayer(String playerId) {
    // TODO: Implement get logic
    return null;
  }

  void approveRequest(String requestId) {
    // TODO: Implement approve logic
    notifyListeners();
  }
}
