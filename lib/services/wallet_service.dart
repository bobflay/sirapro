import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import 'api_service.dart';

/// Service for wallet-related API operations
class WalletService {
  final ApiService _apiService = ApiService();

  /// Get wallet balance and recent transactions
  ///
  /// Calls GET /api/wallet
  /// Returns [WalletResponse] with wallet data and recent transactions
  Future<WalletResponse> getWallet() async {
    try {
      debugPrint('[WalletService] Fetching wallet data...');

      final response = await _apiService.get('/api/wallet');

      debugPrint('[WalletService] Response received: $response');

      if (response is Map<String, dynamic>) {
        return WalletResponse.fromJson(response);
      }

      throw ApiException('Invalid response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[WalletService] Error fetching wallet: $e');
      throw ApiException('Une erreur est survenue lors du chargement du portefeuille');
    }
  }

  /// Get paginated transaction history
  ///
  /// Calls GET /api/wallet/transactions?page={page}
  /// Returns [TransactionsResponse] with transactions list and pagination info
  Future<TransactionsResponse> getTransactions({int page = 1}) async {
    try {
      debugPrint('[WalletService] Fetching transactions (page $page)...');

      final response = await _apiService.get('/api/wallet/transactions?page=$page');

      debugPrint('[WalletService] Response received: $response');

      if (response is Map<String, dynamic>) {
        return TransactionsResponse.fromJson(response);
      }

      throw ApiException('Invalid response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[WalletService] Error fetching transactions: $e');
      throw ApiException('Une erreur est survenue lors du chargement des transactions');
    }
  }
}
