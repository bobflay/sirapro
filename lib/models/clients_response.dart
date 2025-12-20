import 'client.dart';

/// Pagination metadata from the API response
class PaginationMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int? from;
  final int? to;

  PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.from,
    this.to,
  });

  /// Check if there is a next page
  bool get hasNextPage => currentPage < lastPage;

  /// Check if there is a previous page
  bool get hasPreviousPage => currentPage > 1;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    // Handle total which can be either int or List<int> in the API
    int totalValue;
    if (json['total'] is List) {
      totalValue = (json['total'] as List).first as int;
    } else {
      totalValue = json['total'] as int;
    }

    return PaginationMeta(
      currentPage: json['current_page'] as int? ?? json['page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? json['limit'] as int? ?? 20,
      total: totalValue,
      from: json['from'] as int?,
      to: json['to'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': perPage,
      'total': total,
      'from': from,
      'to': to,
    };
  }
}

/// Response model for the GET /api/clients endpoint
class ClientsResponse {
  final List<Client> clients;
  final PaginationMeta meta;
  final bool success;

  ClientsResponse({
    required this.clients,
    required this.meta,
    required this.success,
  });

  /// Check if there are more pages to load
  bool get hasMore => meta.hasNextPage;

  /// Get the next page number
  int? get nextPage => meta.hasNextPage ? meta.currentPage + 1 : null;

  factory ClientsResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>;
    final clients = dataList
        .map((item) => Client.fromJson(item as Map<String, dynamic>))
        .toList();

    return ClientsResponse(
      clients: clients,
      meta: PaginationMeta.fromJson(json['meta'] as Map<String, dynamic>),
      success: json['success'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': clients.map((c) => c.toJson()).toList(),
      'meta': meta.toJson(),
      'success': success,
    };
  }
}
