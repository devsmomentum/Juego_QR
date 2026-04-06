import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MinigameBlockStatus {
  final bool blocked;
  final DateTime? blockedUntil;
  final String? reason;

  const MinigameBlockStatus({
    required this.blocked,
    this.blockedUntil,
    this.reason,
  });

  factory MinigameBlockStatus.fromJson(Map<String, dynamic> json) {
    return MinigameBlockStatus(
      blocked: json['blocked'] == true,
      blockedUntil: json['blocked_until'] != null
          ? DateTime.tryParse(json['blocked_until'] as String)
          : null,
      reason: json['reason']?.toString(),
    );
  }
}

class MinigameStartResult {
  final String? sessionId;
  final MinigameBlockStatus? blockStatus;
  final String? error;

  const MinigameStartResult({
    this.sessionId,
    this.blockStatus,
    this.error,
  });

  bool get isBlocked => blockStatus?.blocked == true;
  bool get isSuccess => sessionId != null && error == null && !isBlocked;
}

class MinigameSubmitResult {
  final bool success;
  final String? errorCode;
  final String userMessage;
  final Map<String, dynamic>? payload;

  const MinigameSubmitResult({
    required this.success,
    required this.userMessage,
    this.errorCode,
    this.payload,
  });
}

class MinigameService {
  MinigameService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<MinigameBlockStatus> precheckBlocked() async {
    try {
      final response = await _supabase.functions.invoke(
        'minigame-handshake',
        body: const {
          'action': 'status',
        },
        method: HttpMethod.post,
      );

      if (response.status != 200 || response.data == null) {
        return const MinigameBlockStatus(blocked: false);
      }

      final data = response.data as Map<String, dynamic>;
      return MinigameBlockStatus.fromJson(data);
    } catch (e) {
      debugPrint('[MinigameService] precheckBlocked error: $e');
      return const MinigameBlockStatus(blocked: false);
    }
  }

  Future<MinigameStartResult> startSession({
    required int clueId,
    required int minDurationSeconds,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'minigame-handshake',
        body: {
          'action': 'start',
          'clueId': clueId,
          'minDurationSeconds': minDurationSeconds,
        },
        method: HttpMethod.post,
      );

      if (response.status != 200 || response.data == null) {
        return const MinigameStartResult(
          error: 'No se pudo iniciar el minijuego',
        );
      }

      final data = response.data as Map<String, dynamic>;
      return MinigameStartResult(sessionId: data['session_id']?.toString());
    } catch (e) {
      debugPrint('[MinigameService] startSession error: $e');
      return const MinigameStartResult(
        error: 'No se pudo iniciar el minijuego',
      );
    }
  }

  Future<MinigameSubmitResult> submitResult({
    required String sessionId,
    required String answer,
    Map<String, dynamic>? result,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'minigame-handshake',
        body: {
          'action': 'verify',
          'sessionId': sessionId,
          'answer': answer,
          'result': result ?? {},
        },
        method: HttpMethod.post,
      );

      if (response.status != 200 || response.data == null) {
        return const MinigameSubmitResult(
          success: false,
          userMessage: 'No se pudo validar el resultado. Intenta de nuevo.',
        );
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return MinigameSubmitResult(
          success: true,
          userMessage: 'Validacion exitosa',
          payload: data,
        );
      }

      final errorCode = data['error']?.toString();
      return MinigameSubmitResult(
        success: false,
        errorCode: errorCode,
        userMessage: 'No se pudo validar el resultado. Intenta de nuevo.',
        payload: data,
      );
    } catch (e) {
      debugPrint('[MinigameService] submitResult error: $e');
      return const MinigameSubmitResult(
        success: false,
        userMessage: 'No se pudo validar el resultado. Intenta de nuevo.',
      );
    }
  }
}
