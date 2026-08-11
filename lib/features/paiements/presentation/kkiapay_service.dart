import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/api_client.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// KKiaPay SERVICE — Intégration Mobile Money côté Flutter
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Ce service gère :
/// - La récupération de la configuration publique (clé publique, sandbox)
/// - L'initiation d'une transaction (appel backend qui crée le record)
/// - La vérification du statut (appel backend qui vérifie server-to-server)
///
/// SÉCURITÉ : La clé PRIVÉE n'est JAMAIS côté Flutter.
/// La vérification du statut se fait toujours server-to-server (backend ↔ KKiaPay).
///
class KkiapayService {
  final ApiClient _apiClient;

  KkiapayService({required ApiClient apiClient}) : _apiClient = apiClient;

  KkiapayConfig? _config;

  /// Récupère la configuration publique KKiaPay (clé publique, mode sandbox)
  Future<KkiapayConfig> getConfig() async {
    if (_config != null) return _config!;

    try {
      final response = await _apiClient.get('/kkiapay/config');
      final data = response.data as Map<String, dynamic>;
      final configData = data['data'] as Map<String, dynamic>;

      _config = KkiapayConfig(
        publicKey: configData['publicKey'] as String? ?? '',
        sandbox: configData['sandbox'] as bool? ?? true,
        apiUrl: configData['apiUrl'] as String? ?? 'https://api.kkiapay.io',
      );

      return _config!;
    } catch (e) {
      AppLogger.e('[KKiaPay] Erreur récupération config: $e');
      // Retourner une config par défaut pour le mode dev
      return KkiapayConfig(
        publicKey: '',
        sandbox: true,
        apiUrl: 'https://api.kkiapay.io',
      );
    }
  }

  /// Initie une transaction KKiaPay pour un paiement chauffeur.
  /// Retourne le transactionId à passer au widget KKiaPay.
  Future<KkiapayInitResult> initierTransaction({
    required String vehiculeId,
    required double montant,
    String? date,
  }) async {
    try {
      final response = await _apiClient.post('/kkiapay/paiements/initier', data: {
        'vehicule_id': vehiculeId,
        'montant': montant,
        if (date != null) 'date': date,
      });

      final data = response.data as Map<String, dynamic>;
      final result = data['data'] as Map<String, dynamic>;

      AppLogger.i('[KKiaPay] Transaction initiée: ${result['transactionId']}');

      return KkiapayInitResult(
        transactionId: result['transactionId'] as String,
        statut: result['statut'] as String? ?? 'initiated',
        message: result['message'] as String? ?? '',
      );
    } catch (e) {
      AppLogger.e('[KKiaPay] Erreur initiation: $e');
      rethrow;
    }
  }

  /// Vérifie le statut RÉEL d'une transaction (server-to-server)
  /// et crée le paiement en base si confirmé.
  ///
  /// C'est CETTE fonction qui confirme le paiement — jamais le callback client.
  Future<KkiapayVerificationResult> verifierTransaction({
    required String transactionId,
    required String vehiculeId,
    required double montant,
    String? date,
  }) async {
    try {
      final response = await _apiClient.post('/kkiapay/paiements/verifier', data: {
        'transaction_id': transactionId,
        'vehicule_id': vehiculeId,
        'montant': montant,
        if (date != null) 'date': date,
      });

      final data = response.data as Map<String, dynamic>;
      final success = data['success'] as bool;

      if (success) {
        final resultData = data['data'] as Map<String, dynamic>;
        final paiementData = resultData['paiement'] as Map<String, dynamic>;
        final soldeData = resultData['solde'] as Map<String, dynamic>;

        AppLogger.i('[KKiaPay] Transaction vérifiée et paiement créé: $transactionId');

        return KkiapayVerificationResult(
          success: true,
          paiementId: paiementData['id'] as String?,
          solde: SoldeKkiapay(
            totalVerseAvant: double.tryParse(soldeData['total_verse_avant'].toString()) ?? 0,
            montantPaye: double.tryParse(soldeData['montant_paye'].toString()) ?? 0,
            nouveauSolde: double.tryParse(soldeData['nouveau_solde'].toString()) ?? 0,
            pourcentageRembourse: double.tryParse(soldeData['pourcentage_rembourse'].toString()) ?? 0,
          ),
          message: data['message'] as String? ?? 'Paiement confirmé',
        );
      } else {
        AppLogger.w('[KKiaPay] Transaction non confirmée: ${data['message']}');
        return KkiapayVerificationResult(
          success: false,
          message: data['message'] as String? ?? 'Transaction non confirmée',
        );
      }
    } catch (e) {
      AppLogger.e('[KKiaPay] Erreur vérification: $e');
      return KkiapayVerificationResult(
        success: false,
        message: 'Erreur de communication: $e',
      );
    }
  }
}

// ─── Modèles ─────────────────────────────────────────────────────────────────

/// Configuration publique KKiaPay (safe à exposer côté client)
class KkiapayConfig {
  final String publicKey;
  final bool sandbox;
  final String apiUrl;

  const KkiapayConfig({
    required this.publicKey,
    required this.sandbox,
    required this.apiUrl,
  });

  bool get isReady => publicKey.isNotEmpty;
}

/// Résultat de l'initiation d'une transaction
class KkiapayInitResult {
  final String transactionId;
  final String statut;
  final String message;

  const KkiapayInitResult({
    required this.transactionId,
    required this.statut,
    required this.message,
  });
}

/// Résultat de la vérification d'une transaction
class KkiapayVerificationResult {
  final bool success;
  final String? paiementId;
  final SoldeKkiapay? solde;
  final String message;

  const KkiapayVerificationResult({
    required this.success,
    this.paiementId,
    this.solde,
    required this.message,
  });
}

/// Information de solde après un paiement KKiaPay
class SoldeKkiapay {
  final double totalVerseAvant;
  final double montantPaye;
  final double nouveauSolde;
  final double pourcentageRembourse;

  const SoldeKkiapay({
    required this.totalVerseAvant,
    required this.montantPaye,
    required this.nouveauSolde,
    required this.pourcentageRembourse,
  });
}

/// Statut du widget KKiaPay (les 4 états du callback SDK)
enum KkiapayWidgetStatus {
  paymentInit,      // Le widget s'est ouvert
  pendingPayment,   // En attente de confirmation du client
  paymentSuccess,   // Le client a complété le paiement (côté widget)
  paymentCancelled, // Le client a annulé
}

// ─── Providers ───────────────────────────────────────────────────────────────

final kkiapayServiceProvider = Provider<KkiapayService>((ref) {
  return KkiapayService(apiClient: ref.read(apiClientProvider));
});

final kkiapayConfigProvider = FutureProvider<KkiapayConfig>((ref) {
  return ref.read(kkiapayServiceProvider).getConfig();
});
