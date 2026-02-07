/// Resultado de usar un poder.
enum PowerUseResultType { success, reflected, error }

/// Respuesta detallada del uso de un poder.
class PowerUseResponse {
  final PowerUseResultType result;
  final bool wasReturned;
  final String? returnedByName;
  final bool stealFailed;
  final String? stealFailReason;
  final bool blockedByShield;
  final String? errorMessage;

  PowerUseResponse({
    required this.result,
    this.wasReturned = false,
    this.returnedByName,
    this.stealFailed = false,
    this.stealFailReason,
    this.blockedByShield = false,
    this.errorMessage,
  });

  factory PowerUseResponse.success() => PowerUseResponse(
        result: PowerUseResultType.success,
      );
  
  factory PowerUseResponse.blocked() => PowerUseResponse(
        result: PowerUseResultType.success, // Technically success execution, but blocked effect
        blockedByShield: true,
      );

  factory PowerUseResponse.reflected(String byName) => PowerUseResponse(
        result: PowerUseResultType.reflected,
        wasReturned: true,
        returnedByName: byName,
      );

  factory PowerUseResponse.error(String message) => PowerUseResponse(
        result: PowerUseResultType.error,
        errorMessage: message,
      );

  static PowerUseResponse fromRpcResponse(dynamic response) {
    // 1. Check for explicit success/failure
    if (response is Map) {
      if (response['success'] == false) {
        final error = response['error'];
         if (error == 'unauthorized') return PowerUseResponse.error('No tienes permiso para usar este poder');
         if (error == 'target_invisible') return PowerUseResponse.error('¡El objetivo es invisible!');
         if (error == 'shield_already_active') return PowerUseResponse.error('¡El escudo ya está activo!');
         return PowerUseResponse.error(error?.toString() ?? 'Error desconocido');
      }
      
      // 2. Check for blocked
      if (response['blocked'] == true) {
        return PowerUseResponse.blocked();
      }

      // 3. Check for returned
      if (response['returned'] == true) {
        return PowerUseResponse.reflected(response['returned_by_name'] ?? 'Un rival');
      }

      // 4. Check for steal fail
      if (response['stolen'] == false && response['reason'] == 'target_no_lives') {
        return PowerUseResponse(
          result: PowerUseResultType.success,
          stealFailed: true,
          stealFailReason: 'target_no_lives',
        );
      }
    }

    // 5. Handle scalars (bool, string, int)
    if (response is bool && response == false) return PowerUseResponse.error('Falló la ejecución del poder');
    if (response is String && response.toLowerCase() == 'false') return PowerUseResponse.error('Falló la ejecución del poder');

    // Default success if no error structure found
    return PowerUseResponse.success();
  }
}

/// Información de rivales para broadcast de poderes.
class RivalInfo {
  final String gamePlayerId;
  RivalInfo(this.gamePlayerId);
}
