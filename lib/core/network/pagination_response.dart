class PaginationMeta {
  final int currentPage;
  final int lastPage;
  final int total;

  PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      total: json['total'] ?? 0,
    );
  }
}

class PaginationResponse<T> {
  final List<T> data;
  final PaginationMeta meta;

  PaginationResponse({
    required this.data,
    required this.meta,
  });

  factory PaginationResponse.fromJson(
      Map<String, dynamic> json, T Function(Object? json) fromJsonT) {
    return PaginationResponse(
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => fromJsonT(e))
              .toList() ??
          [],
      meta: PaginationMeta.fromJson(json['meta'] ?? {}),
    );
  }
}
