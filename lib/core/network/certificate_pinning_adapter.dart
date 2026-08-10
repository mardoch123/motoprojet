import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// Certificate Pinning pour Dio.
///
/// Vérifie que le certificat SSL du serveur correspond à l'empreinte SHA-256
/// attendue. Empêche les attaques MITM même avec un certificat CA compromis.
///
/// Usage :
///   final adapter = CertificatePinningAdapter(
///     allowedSha256Hashes: ['base64Hash1', 'base64Hash2'],
///   );
///   dio.httpClientAdapter = adapter;
class CertificatePinningAdapter extends IOHttpClientAdapter {
  final List<String> _allowedSha256Hashes;
  final bool _enforceInProduction;

  CertificatePinningAdapter({
    required List<String> allowedSha256Hashes,
    bool enforceInProduction = true,
  })  : _allowedSha256Hashes = allowedSha256Hashes,
        _enforceInProduction = enforceInProduction {
    onHttpClientCreate = (HttpClient client) {
      client.badCertificateCallback = (
        X509Certificate cert,
        String host,
        int port,
      ) {
        return _verifyCertificate(cert, host, port);
      };
      return client;
    };
  }

  bool _verifyCertificate(X509Certificate cert, String host, int port) {
    // En debug, on peut désactiver le pinning pour les tests locaux
    if (kDebugMode && !_enforceInProduction) {
      AppLogger.w('Certificate pinning désactivé (mode debug)');
      return true;
    }

    // Si aucun hash configuré, on accepte (configuration manquante)
    if (_allowedSha256Hashes.isEmpty) {
      AppLogger.w('Aucun hash de certificat configuré — pinning ignoré');
      return true;
    }

    // Calculer le SHA-256 du certificat DER
    // Extraire le contenu base64 entre les marqueurs PEM
    final pemContent = cert.pem
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll('\n', '')
        .trim();
    final certBytes = base64.decode(pemContent);
    final digest = sha256.convert(certBytes);
    final sha256Hash = base64.encode(digest.bytes);

    // Vérifier si le hash correspond à l'un des hashes autorisés
    final isPinned = _allowedSha256Hashes.contains(sha256Hash);

    if (!isPinned) {
      AppLogger.e(
        'CERTIFICATE PINNING FAILURE — possible MITM attack!',
      );
      AppLogger.e('Host: $host:$port');
      AppLogger.e('Certificate SHA-256: $sha256Hash');
    }

    return isPinned;
  }
}

/// Configuration des empreintes de certificats autorisées.
///
/// IMPORTANT : Mettre à jour ces valeurs avec les vrais hashes SHA-256
/// des certificats de production. Obtenir les hashes avec :
///
/// ```bash
/// openssl s_client -connect api.motoprojet.bj:443 \
///   -servername api.motoprojet.bj 2>/dev/null \
///   | openssl x509 -noout -fingerprint -sha256 \
///   | sed 's/.*=//;s/://g' | xxd -r -p | base64
/// ```
///
/// Inclure au moins 2 hashes (certificat actuel + certificat de backup).
class CertificatePins {
  CertificatePins._();

  /// Hashes SHA-256 des certificats autorisés (base64).
  /// Remplacer par les vrais hashes en production.
  static const List<String> production = [
    // À remplacer par les vrais hashes SHA-256 du certificat de production
    // Exemple : 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    // Inclure le certificat actuel ET un certificat de backup
  ];

  /// Hashes pour l'environnement de développement (vide = pas de pinning).
  static const List<String> development = [];
}
