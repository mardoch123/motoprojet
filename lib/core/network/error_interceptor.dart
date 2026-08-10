import 'package:dio/dio.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Intercepteur qui gère les erreurs réseau de manière centralisée
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        AppLogger.e('Délai de connexion dépassé');
        break;
      case DioExceptionType.sendTimeout:
        AppLogger.e('Délai d\'envoi dépassé');
        break;
      case DioExceptionType.receiveTimeout:
        AppLogger.e('Délai de réception dépassé');
        break;
      case DioExceptionType.badResponse:
        _handleBadResponse(err);
        break;
      case DioExceptionType.cancel:
        AppLogger.w('Requête annulée');
        break;
      case DioExceptionType.connectionError:
        AppLogger.e('Erreur de connexion réseau');
        break;
      default:
        AppLogger.e('Erreur inattendue: ${err.message}');
    }
    handler.next(err);
  }

  void _handleBadResponse(DioException err) {
    final statusCode = err.response?.statusCode;
    switch (statusCode) {
      case 400:
        AppLogger.e('Requête invalide (400)');
        break;
      case 401:
        AppLogger.e('Non authentifié (401) - Token expiré ou invalide');
        // Le AuthTokenInterceptor gérera le refresh
        break;
      case 403:
        AppLogger.e('Accès refusé (403)');
        break;
      case 404:
        AppLogger.e('Ressource non trouvée (404)');
        break;
      case 409:
        AppLogger.e('Conflit de données (409)');
        break;
      case 422:
        AppLogger.e('Données invalides (422)');
        break;
      case 429:
        AppLogger.e('Trop de requêtes (429)');
        break;
      case 500:
        AppLogger.e('Erreur serveur (500)');
        break;
      case 502:
        AppLogger.e('Passerelle invalide (502)');
        break;
      case 503:
        AppLogger.e('Service indisponible (503)');
        break;
      default:
        AppLogger.e('Erreur HTTP $statusCode');
    }
  }
}
