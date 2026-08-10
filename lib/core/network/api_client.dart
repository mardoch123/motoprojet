import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:motoprojet/core/config/app_config.dart';
import 'package:motoprojet/core/constants/app_constants.dart';
import 'package:motoprojet/core/network/auth_interceptor.dart';
import 'package:motoprojet/core/network/certificate_pinning_adapter.dart';
import 'package:motoprojet/core/network/error_interceptor.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Client HTTP central basé sur Dio, configuré avec intercepteurs JWT et erreurs.
/// En production, utilise le certificate pinning pour prévenir les attaques MITM.
class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  ApiClient({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: Duration(milliseconds: AppConfig.apiTimeout),
        receiveTimeout: Duration(milliseconds: AppConfig.apiTimeout),
        sendTimeout: Duration(milliseconds: AppConfig.apiTimeout),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Certificate pinning en production
    if (kReleaseMode && CertificatePins.production.isNotEmpty) {
      _dio.httpClientAdapter = CertificatePinningAdapter(
        allowedSha256Hashes: CertificatePins.production,
        enforceInProduction: true,
      );
      AppLogger.i('Certificate pinning activé (production)');
    }

    _dio.interceptors.addAll([
      AuthInterceptor(_secureStorage),
      ErrorInterceptor(),
      // Logger pretty uniquement en debug
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
        ),
    ]);

    AppLogger.i('ApiClient initialisé → ${AppConfig.apiBaseUrl}');
  }

  Dio get instance => _dio;

  // ─── GET ────────────────────────────────────────────────────────────────────
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(path,
        queryParameters: queryParameters, options: options);
  }

  // ─── POST ───────────────────────────────────────────────────────────────────
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  // ─── PUT ────────────────────────────────────────────────────────────────────
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.put<T>(path, data: data, options: options);
  }

  // ─── PATCH ──────────────────────────────────────────────────────────────────
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.patch<T>(path, data: data, options: options);
  }

  // ─── DELETE ─────────────────────────────────────────────────────────────────
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.delete<T>(path, data: data, options: options);
  }

  // ─── Rafraîchir le token ───────────────────────────────────────────────────
  Future<void> refreshToken(String newToken) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: newToken);
  }

  // ─── Effacer les tokens (déconnexion) ──────────────────────────────────────
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.userRoleKey);
    await _secureStorage.delete(key: AppConstants.userIdKey);
  }
}
