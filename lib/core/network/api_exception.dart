class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const ApiException({required this.message, this.statusCode, this.details});

  @override
  String toString() =>
      'ApiException($statusCode): $message${details != null ? '\nDetails: $details' : ''}';
}
