import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_withdrawal_request.dart';

class WithdrawalActionResult {
  final bool success;
  final String message;

  WithdrawalActionResult({required this.success, required this.message});
}

class WithdrawalRequestRepository {
  final SupabaseClient _supabase;

  WithdrawalRequestRepository({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Fetches withdrawal requests with optional status filter.
  Future<List<AdminWithdrawalRequest>> fetchRequests({String? status}) async {
    try {
      final response = await _supabase.rpc(
        'get_withdrawal_requests_with_profiles',
        params: {'p_status': status ?? 'all'},
      );
      
      return (response as List)
          .map((data) => AdminWithdrawalRequest.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('WithdrawalRequestRepository: Error fetching requests: $e');
      rethrow;
    }
  }

  /// Marks a withdrawal as completed using the mark_withdrawal_completed RPC.
  Future<WithdrawalActionResult> markAsCompleted(String requestId, Map<String, dynamic> providerData) async {
    try {
      final result = await _supabase.rpc('mark_withdrawal_completed', params: {
        'p_request_id': requestId,
        'p_provider_data': providerData,
      });
      
      return WithdrawalActionResult(
        success: true,
        message: result?['message'] ?? 'Retiro completado',
      );
    } on PostgrestException catch (e) {
      debugPrint('WithdrawalRequestRepository: PostgrestError completing request: ${e.message}');
      return WithdrawalActionResult(success: false, message: e.message);
    } catch (e) {
      debugPrint('WithdrawalRequestRepository: Error completing request: $e');
      return WithdrawalActionResult(success: false, message: e.toString());
    }
  }

  /// Marks a withdrawal as failed using the mark_withdrawal_failed RPC.
  Future<WithdrawalActionResult> markAsFailed(String requestId, Map<String, dynamic> providerData, {bool refund = true}) async {
    try {
      final result = await _supabase.rpc('mark_withdrawal_failed', params: {
        'p_request_id': requestId,
        'p_provider_data': providerData,
        'p_refund': refund,
      });
      
      return WithdrawalActionResult(
        success: true,
        message: result?['message'] ?? 'Retiro rechazado',
      );
    } on PostgrestException catch (e) {
      debugPrint('WithdrawalRequestRepository: PostgrestError failing request: ${e.message}');
      return WithdrawalActionResult(success: false, message: e.message);
    } catch (e) {
      debugPrint('WithdrawalRequestRepository: Error failing request: $e');
      return WithdrawalActionResult(success: false, message: e.toString());
    }
  }
}
