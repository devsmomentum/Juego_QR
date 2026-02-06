import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_item.dart';

abstract class ITransactionRepository {
  Future<List<TransactionItem>> getMyTransactions();
}

class SupabaseTransactionRepository implements ITransactionRepository {
  final SupabaseClient _supabase;

  SupabaseTransactionRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<TransactionItem>> getMyTransactions() async {
    try {
      final response = await _supabase
          .from('user_activity_feed')
          .select('*')
          .order('created_at', ascending: false);

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => TransactionItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Error cargando transacciones: $e');
    }
  }
}
