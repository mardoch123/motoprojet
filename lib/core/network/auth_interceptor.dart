import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:motoprojet/core/config/app_config.dart';
import 'package:motoprojet/core/constants/app_constants.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Intercepteur d'authentification avec rafraîchissement automatique du token.
///
/// Comportement :
/// 1. Ajoute le JWT dans le header `Authorization: Bearer <token>`
/// 2. Si une 401 est reçue → tente un refresh via `/api/v1/auth/refresh`
/// 3. Si le refresh réussit → met à jour le token et rejoue la requête
/// 4. Si le refresh échoue → propage l'erreur (l'app redirigera vers le login)
///
/// Utilise `QueuedInterceptor` pour sérialiser les refreshes : si plusieurs
/// requêtes échouent simultanément avec 401, une seule sera envoyée au
/// endpoint /refresh, les autres attendront le résultat.
class AuthInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _secureStorage;

  /// Dio interne utilisé uniquement pour l'appel de refresh token.
  /// Isolé pour éviter les boucles infinies d'intercepteurs.
  final Dio _refreshDio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  AuthInterceptor(this._secureStorage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Ne traiter que les 401 et uniquement si la requête n'est pas déjà un refresh
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshRequest = err.requestOptions.path.contains('/auth/refresh');
    final isLoginRequest = err.requestOptions.path.contains('/auth/login');

    if (!isUnauthorized || isRefreshRequest || isLoginRequest) {
      // Pas une 401, ou c'est déjà une requête de refresh/login → propager
      return handler.next(err);
    }

    AppLogger.i('[AuthInterceptor] 401 détectée — tentative de refresh token');

    try {
      final refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) {
        AppLogger.w('[AuthInterceptor] Pas de refresh token — reconnexion requise');
        return handler.next(err);
      }

      // Appeler l'endpoint de refresh avec un Dio isolé (pas d'intercepteurs)
      final response = await _refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['data']?['access_token'] as String?;

      if (newAccessToken == null) {
        AppLogger.w('[AuthInterceptor] Refresh réussi mais pas de token dans la réponse');
        return handler.next(err);
      }

      // Mettre à jour le token en stockage sécurisé
      await _secureStorage.write(key: AppConstants.tokenKey, value: newAccessToken);
      AppLogger.i('[AuthInterceptor] Token rafraîchi avec succès');

      // Rejouer la requête originale avec le nouveau token
      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryResponse = await _retryRequest(requestOptions);
      return handler.resolve(retryResponse);
    } on DioException catch (refreshErr) {
      // Le refresh a échoué (token expiré ou invalide)
      final statusCode = refreshErr.response?.statusCode;
      AppLogger.w('[AuthInterceptor] Refresh échoué (HTTP $statusCode) — reconnexion requise');

      // Nettoyer les tokens pour forcer la déconnexion
      await _secureStorage.delete(key: AppConstants.tokenKey);
      await _secureStorage.delete(key: AppConstants.refreshTokenKey);

      return handler.next(refreshErr);
    } catch (e) {
      AppLogger.e('[AuthInterceptor] Erreur inattendue lors du refresh: $e');
      return handler.next(err);
    }
  }

  /// Rejoue une requête avec les mêmes options (après refresh du token).
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
