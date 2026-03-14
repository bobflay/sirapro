import 'package:flutter/foundation.dart';
import '../models/return_voucher.dart';
import 'api_service.dart';

/// Service for Return Voucher API operations
class ReturnVoucherService {
  final ApiService _apiService = ApiService();

  /// List return vouchers with optional filters
  Future<ReturnVoucherListResponse> getReturnVouchers({
    String? status,
    int? clientId,
    String? fromDate,
    String? toDate,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null) queryParams['status'] = status;
    if (clientId != null) queryParams['client_id'] = clientId.toString();
    if (fromDate != null) queryParams['from_date'] = fromDate;
    if (toDate != null) queryParams['to_date'] = toDate;

    final queryString = queryParams.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final response =
        await _apiService.get('/api/return-vouchers?$queryString');
    final data = response as Map<String, dynamic>;
    return ReturnVoucherListResponse.fromJson(data);
  }

  /// Get a single return voucher
  Future<ReturnVoucher> getReturnVoucher(int id) async {
    final response = await _apiService.get('/api/return-vouchers/$id');
    final data = response as Map<String, dynamic>;
    return ReturnVoucher.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Create a new return voucher
  Future<ReturnVoucher> createReturnVoucher({
    required int clientId,
    String? notes,
    required List<ReturnVoucherItem> items,
  }) async {
    final body = <String, dynamic>{
      'client_id': clientId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': items.map((item) => item.toCreateJson()).toList(),
    };

    debugPrint('[ReturnVoucherService] Creating return voucher with body: $body');
    for (int i = 0; i < items.length; i++) {
      debugPrint('[ReturnVoucherService] Item[$i]: ${items[i].toCreateJson()}');
    }

    try {
      final response = await _apiService.post(
        '/api/return-vouchers',
        body: body,
      );
      final data = response as Map<String, dynamic>;
      debugPrint('[ReturnVoucherService] Create response: $data');

      if (data['status'] == false) {
        final message =
            data['message'] as String? ?? 'Erreur lors de la création';
        final errors = data['errors'];
        debugPrint('[ReturnVoucherService] Validation errors: $errors');
        if (errors != null && errors is Map<String, dynamic>) {
          final errorMessages = <String>[];
          errors.forEach((key, value) {
            if (value is List) {
              errorMessages.addAll(value.map((e) => e.toString()));
            } else {
              errorMessages.add(value.toString());
            }
          });
          if (errorMessages.isNotEmpty) {
            throw ApiException(errorMessages.join('\n'), statusCode: 422);
          }
        }
        throw ApiException(message, statusCode: 422);
      }

      return ReturnVoucher.fromJson(data['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      debugPrint('[ReturnVoucherService] ApiException: ${e.message} (status: ${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[ReturnVoucherService] Unexpected error: $e');
      rethrow;
    }
  }

  /// Update a draft return voucher
  Future<ReturnVoucher> updateReturnVoucher({
    required int id,
    int? clientId,
    String? notes,
    List<ReturnVoucherItem>? items,
  }) async {
    final body = <String, dynamic>{};
    if (clientId != null) body['client_id'] = clientId;
    if (notes != null) body['notes'] = notes;
    if (items != null) {
      body['items'] = items.map((item) => item.toCreateJson()).toList();
    }

    final response = await _apiService.put(
      '/api/return-vouchers/$id',
      body: body,
    );
    final data = response as Map<String, dynamic>;

    if (data['status'] == false) {
      final message =
          data['message'] as String? ?? 'Erreur lors de la mise à jour';
      throw ApiException(message, statusCode: 422);
    }

    return ReturnVoucher.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Submit a draft return voucher
  Future<ReturnVoucher> submitReturnVoucher(int id) async {
    debugPrint('[ReturnVoucherService] Submitting return voucher id=$id');

    try {
      final response = await _apiService.post(
        '/api/return-vouchers/$id/submit',
      );
      final data = response as Map<String, dynamic>;
      debugPrint('[ReturnVoucherService] Submit response: $data');

      if (data['status'] == false) {
        final message =
            data['message'] as String? ?? 'Erreur lors de la soumission';
        debugPrint('[ReturnVoucherService] Submit error: $message');
        throw ApiException(message, statusCode: 422);
      }

      return ReturnVoucher.fromJson(data['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      debugPrint('[ReturnVoucherService] Submit ApiException: ${e.message} (status: ${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[ReturnVoucherService] Submit unexpected error: $e');
      rethrow;
    }
  }
}

/// Response for paginated return voucher list
class ReturnVoucherListResponse {
  final List<ReturnVoucher> vouchers;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  ReturnVoucherListResponse({
    required this.vouchers,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  bool get hasMorePages => currentPage < lastPage;

  factory ReturnVoucherListResponse.fromJson(Map<String, dynamic> json) {
    final dataMap = json['data'] as Map<String, dynamic>;
    final dataList = dataMap['data'] as List<dynamic>;

    return ReturnVoucherListResponse(
      vouchers: dataList
          .map((item) =>
              ReturnVoucher.fromJson(item as Map<String, dynamic>))
          .toList(),
      currentPage: dataMap['current_page'] as int? ?? 1,
      lastPage: dataMap['last_page'] as int? ?? 1,
      total: dataMap['total'] as int? ?? 0,
      perPage: dataMap['per_page'] as int? ?? 20,
    );
  }
}
