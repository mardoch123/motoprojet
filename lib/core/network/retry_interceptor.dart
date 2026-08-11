import 'dart:math';

import 'package:dio/dio.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Intercepteur de retry automatique pour les erreurs réseau transitoires.
///
/// Erreurs retriables :
/// - Timeouts (connexion, envoi, réception)
/// - Erreurs de connexion réseau
/// - HTTP 502 (Bad Gateway)
/// - HTTP 503 (Service Unavailable)
/// - HTTP 504 (Gateway Timeout)
///
/// Stratégie : backoff exponentiel avec jitter pour éviter l'effet thundering herd.
/// Délais : ~1s, ~2s, ~4s (max 3 tentatives).
///
/// Ne retry PAS :
/// - Les requêtes POST/PUT/PATCH/DELETE non-idempotentes (sauf 502/503)
/// - Les erreurs 4xx (erreur client, pas transitoire)
/// - Les erreurs d'annulation
class RetryInterceptor extends Interceptor {
  /// Nombre maximum de tentatives (1 = pas de retry)
  final int maxRetries;

  /// Délai de base en millisecondes avant le premier retry
  final int baseDelayMs;

  /// Codes HTTP considérés comme transitoires
  static const Set<int> _retryableStatusCodes = {502, 503, 504};

  /// Méthodes HTTP considérées comme sûrement retriabl (idempotentes)
  static const Set<String> _idempotentMethods = {'GET', 'HEAD', 'OPTIONS'};

  RetryInterceptor({
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final shouldRetry = _shouldRetry(err);

    if (!shouldRetry) {
      return handler.next(err);
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final delay = _calculateDelay(attempt);
      AppLogger.w(
        '[Retry] Tentative $attempt/$maxRetries après ${delay}ms '
        '(${err.type.name}, ${err.requestOptions.method} ${err.requestOptions.path})',
      );

      await Future.delayed(Duration(milliseconds: delay));

      try {
        final response = await _retryRequest(err.requestOptions);
        AppLogger.i('[Retry] Succès à la tentative $attempt');
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        if (attempt == maxRetries || !_shouldRetry(retryErr)) {
          AppLogger.e('[Retry] Échec après $attempt tentatives: ${retryErr.type.name}');
          return handler.next(retryErr);
        }
        // Continuer au prochain retry
      }
    }

    return handler.next(err);
  }

  /// Détermine si une erreur est retriblable
  bool _shouldRetry(DioException err) {
    // Les erreurs de timeout sont toujours retriabl
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return true;
    }

    // Les erreurs de connexion sont retriabl
    if (err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Les erreurs HTTP 502/503/504 sont retriabl pour les méthodes idempotentes
    if (err.type == DioExceptionType.badResponse) {
      final statusCode = err.response?.statusCode;
      if (statusCode != null && _retryableStatusCodes.contains(statusCode)) {
        final method = err.requestOptions.method.toUpperCase();
        // Pour les méthodes non-idempotentes, on retry uniquement si 502/503
        // (le serveur n'a probablement pas traité la requête)
        if (_idempotentMethods.contains(method)) return true;
        // POST/PUT/PATCH : retry uniquement sur 502/503 (pas 504 = timeout serveur)
        if (statusCode == 502 || statusCode == 503) return true;
      }
    }

    return false;
  }

  /// Calcule le délai avec backoff exponentiel + jitter
  int _calculateDelay(int attempt) {
    final exponential = baseDelayMs * pow(2, attempt - 1).toInt();
    final jitter = Random().nextInt(max(exponential ~/ 2, 1));
    return min(exponential + jitter, 10000); // Max 10 secondes
  }

  /// Rejoue une requête
  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    final dio = Dio(BaseOptions(
      baseUrl: options.baseUrl,
      connectTimeout: options.connectTimeout,
      receiveTimeout: options.receiveTimeout,
      sendTimeout: options.sendTimeout,
    ));

    switch (options.method) {
      case 'GET':
        return dio.get(
          options.path,
          queryParameters: options.queryParameters,
          options: Options(headers: options.headers),
        );
      case 'POST':
        return dio.post(
          options.path,
          data: options.data,
          queryParameters: options.queryParameters,
          options: Options(headers: options.headers),
        );
      case 'PUT':
        return dio.put(
          options.path,
          data: options.data,
          options: Options(headers: options.headers),
        );
      case 'PATCH':
        return dio.patch(
          options.path,
          data: options.data,
          options: Options(headers: options.headers),
        );
      case 'DELETE':
        return dio.delete(
          options.path,
          data: options.data,
          options: Options(headers: options.headers),
        );
      default:
        return dio.get(
          options.path,
          queryParameters: options.queryParameters,
          options: Options(headers: options.headers),
        );
    }
  }
}
