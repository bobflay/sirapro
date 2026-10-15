import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/wallet.dart';
import 'api_service.dart';
import 'offline_queue_service.dart';

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

  /// Clé de [OfflineOperation.meta] décrivant une livraison mise en file :
  /// {order, item, product, amount, delivered}.
  static const String deliveryMetaKey = 'wallet_delivery';

  /// Métadonnées à joindre à une livraison mise en file hors ligne, pour
  /// qu'elle apparaisse dans les transactions avant sa synchronisation.
  static Map<String, dynamic> deliveryMeta({
    required String orderReference,
    required String itemKey,
    required String productName,
    required double amount,
    required bool delivered,
  }) =>
      {
        deliveryMetaKey: {
          'order': orderReference,
          'item': itemKey,
          'product': productName,
          'amount': amount,
          'delivered': delivered,
        },
      };

  /// Crédits des livraisons faites hors ligne et pas encore synchronisées.
  ///
  /// En ligne, le serveur crédite le portefeuille à chaque article livré ;
  /// hors ligne, ces transactions sont reconstituées depuis la file d'attente
  /// et disparaissent d'elles-mêmes une fois envoyées (la version serveur
  /// prend alors le relais). Pour un même article, le dernier marquage
  /// l'emporte : livré puis « non livré » ne crédite rien.
  Future<List<WalletTransaction>> pendingDeliveryCredits() async {
    final latest = <String, Map<String, dynamic>>{};
    final dates = <String, DateTime>{};
    for (final op in await OfflineQueueService().pendingOperations()) {
      final delivery = op.meta?[deliveryMetaKey];
      if (delivery is! Map<String, dynamic>) continue;
      final key = '${delivery['order']}|${delivery['item']}';
      latest[key] = delivery;
      dates[key] = op.createdAt;
    }

    var localId = 0;
    return [
      for (final entry in latest.entries)
        if (entry.value['delivered'] == true)
          WalletTransaction(
            id: --localId,
            type: 'credit',
            amount: (entry.value['amount'] as num?)?.toDouble() ?? 0,
            balanceAfter: 0,
            description: 'Livraison — ${entry.value['product']}',
            createdAt: dates[entry.key]!,
            pendingReference: entry.value['order'] as String?,
          ),
    ];
  }

  /// Submit a cash receipt for balance deduction
  ///
  /// Calls POST /api/cash-receipts with multipart/form-data
  /// [imageBytes] - The receipt image bytes
  /// [fileName] - The image file name (e.g. 'receipt.jpg')
  /// [amount] - The amount to deduct (min 0.01)
  /// [notes] - Optional notes (max 1000 chars)
  /// Returns the parsed JSON response
  Future<Map<String, dynamic>> submitCashReceipt({
    required Uint8List imageBytes,
    required String fileName,
    required double amount,
    String? notes,
  }) async {
    try {
      debugPrint('[WalletService] Submitting cash receipt (amount: $amount)...');

      final uri = Uri.parse('${ApiService.baseUrl}/api/cash-receipts');
      final request = http.MultipartRequest('POST', uri);

      // Auth header
      final token = _apiService.token;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      // Determine content type from file name
      final extension = fileName.split('.').last.toLowerCase();
      String mimeType;
      switch (extension) {
        case 'png':
          mimeType = 'image/png';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      // Add image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Add amount field
      request.fields['amount'] = amount.toString();

      // Add notes if provided
      if (notes != null && notes.trim().isNotEmpty) {
        request.fields['notes'] = notes.trim();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[WalletService] Cash receipt response: ${response.statusCode}');

      final body = response.body.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(response.body) as Map)
          : <String, dynamic>{};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      }

      // Handle validation errors (422)
      if (response.statusCode == 422 && body.containsKey('errors')) {
        final errors = body['errors'] as Map<String, dynamic>;
        final firstError = errors.values.first;
        final errorMessage = firstError is List && firstError.isNotEmpty
            ? firstError.first.toString()
            : body['message']?.toString() ?? 'Erreur de validation';
        throw ApiException(errorMessage, statusCode: 422);
      }

      throw ApiException(
        body['message']?.toString() ?? 'Une erreur est survenue',
        statusCode: response.statusCode,
      );
    } on http.ClientException {
      throw ApiException('Connexion échouée. Vérifiez votre connexion internet.');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[WalletService] Error submitting cash receipt: $e');
      throw ApiException('Une erreur est survenue lors de l\'envoi du reçu');
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

  /// Get list of submitted cash receipts
  ///
  /// Calls GET /api/cash-receipts
  /// Returns [CashReceiptsResponse] with receipts list and pagination
  Future<CashReceiptsResponse> getCashReceipts() async {
    try {
      debugPrint('[WalletService] Fetching cash receipts...');

      final response = await _apiService.get('/api/cash-receipts');

      debugPrint('[WalletService] Cash receipts response received');

      if (response is Map<String, dynamic>) {
        return CashReceiptsResponse.fromJson(response);
      }

      throw ApiException('Invalid response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[WalletService] Error fetching cash receipts: $e');
      throw ApiException('Une erreur est survenue lors du chargement des reçus');
    }
  }
}
