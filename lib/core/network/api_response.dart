/// Résultat standardisé pour les opérations API
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResponse._({this.data, this.error, this.statusCode});

  factory ApiResponse.success(T data, {int? statusCode}) =>
      ApiResponse._(data: data, statusCode: statusCode);

  factory ApiResponse.failure(String error, {int? statusCode}) =>
      ApiResponse._(error: error, statusCode: statusCode);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}
