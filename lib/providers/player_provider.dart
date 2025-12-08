import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';

class PlayerProvider extends ChangeNotifier {
  Player? _currentPlayer;
  final _supabase = Supabase.instance.client;
  
  Player? get currentPlayer => _currentPlayer;
  
  bool get isLoggedIn => _currentPlayer != null;
  
  Future<void> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        await _fetchProfile(response.user!.id);
      }
    } on AuthException catch (e) {
      debugPrint('Auth Error logging in: ${e.message}');
      if (e.message.contains('Invalid login credentials')) {
        throw Exception('Credenciales inválidas o email no confirmado.');
      }
      throw Exception(e.message);
    } catch (e) {
      debugPrint('Error logging in: $e');
      rethrow;
    }
  }
  
  Future<void> register(String name, String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, // This triggers the handle_new_user trigger
      );
      
      if (response.user != null) {
        // Wait a bit for the trigger to create the profile
        await Future.delayed(const Duration(seconds: 1));
        await _fetchProfile(response.user!.id);
      }
    } catch (e) {
      debugPrint('Error registering: $e');
      rethrow;
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      _currentPlayer = Player.fromJson(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // If profile doesn't exist yet (race condition), maybe retry or handle gracefully
    }
  }
  
  Future<void> logout() async {
    await _supabase.auth.signOut();
    _currentPlayer = null;
    notifyListeners();
  }
  
  // Methods below would need to be updated to sync with Supabase DB
  // For now, we'll keep them updating local state, but in a real app 
  // they should call RPCs or update tables.

  void addExperience(int xp) {
    if (_currentPlayer != null) {
      final oldLevel = _currentPlayer!.level;
      _currentPlayer!.addExperience(xp);
      
      if (_currentPlayer!.level > oldLevel) {
        // Level up!
        _currentPlayer!.updateProfession();
      }
      notifyListeners();
    }
  }
  
  void addCoins(int amount) {
    if (_currentPlayer != null) {
      _currentPlayer!.coins += amount;
      notifyListeners();
    }
  }
  
  bool spendCoins(int amount) {
    if (_currentPlayer != null && _currentPlayer!.coins >= amount) {
      _currentPlayer!.coins -= amount;
      notifyListeners();
      return true;
    }
    return false;
  }
  
  void addItemToInventory(String item) {
    if (_currentPlayer != null) {
      _currentPlayer!.addItem(item);
      notifyListeners();
    }
  }
  
  bool useItemFromInventory(String item) {
    if (_currentPlayer != null && _currentPlayer!.removeItem(item)) {
      notifyListeners();
      return true;
    }
    return false;
  }
  
  void freezePlayer(DateTime until) {
    if (_currentPlayer != null) {
      _currentPlayer!.status = PlayerStatus.frozen;
      _currentPlayer!.frozenUntil = until;
      notifyListeners();
    }
  }
  
  void unfreezePlayer() {
    if (_currentPlayer != null) {
      _currentPlayer!.status = PlayerStatus.active;
      _currentPlayer!.frozenUntil = null;
      notifyListeners();
    }
  }
  
  void updateStats(String stat, int value) {
    if (_currentPlayer != null) {
      _currentPlayer!.stats[stat] = (_currentPlayer!.stats[stat] as int) + value;
      _currentPlayer!.updateProfession();
      notifyListeners();
    }
  }

  void sabotageRival(String rivalId) {
    if (_currentPlayer != null && _currentPlayer!.coins >= 50) {
      _currentPlayer!.coins -= 50;
      notifyListeners();
    }
  }
}
