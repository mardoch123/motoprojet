import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/api_client.dart';
import 'package:motoprojet/core/network/connectivity_service.dart';
import 'package:motoprojet/core/network/offline_storage_service.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import 'package:motoprojet/shared/models/paiement_model.dart';
import 'package:uuid/uuid.dart';

/// Parse un montant API (peut être num ou String depuis PostgreSQL)
double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

/// Repository qui gère la bascule online/offline de façon transparente.
///
/// Diagramme de séquence :
/// ```
/// Utilisateur          Repository           API/Offline
///     |                    |                    |
///     |-- enregistrer() -->|                    |
///     |                    |-- isConnected? ---->|
///     |                    |<--- true -----------|
///     |                    |-- POST /paiements ->|
///     |                    |<-- 201 + solde -----|
///     |<-- résultat -------|                    |
///
///     |-- enregistrer() -->|                    |
///     |                    |-- isConnected? ---->|
///     |                    |<--- false ----------|
///     |                    |-- saveOffline ----->|  (Hive)
///     |                    |<-- UUID local ------|
///     |<-- résultat -------|                    |
///     |                    |                    |
///     |        [Connexion revient]              |
///     |                    |<-- onConnectivity --|
///     |                    |-- syncBatch ------>|  (API)
///     |                    |<-- created/dupes --|
///     |                    |-- removeOffline -->|  (Hive)
/// ```
class PaiementRepository {
  final ApiClient apiClient;
  final OfflineStorageService offlineStorage;
  final ConnectivityService connectivity;
  final _uuid = const Uuid();

  PaiementRepository({
    required this.apiClient,
    required this.offlineStorage,
    required this.connectivity,
  });

  /// Enregistre un paiement. Bascule automatiquement online/offline.
  /// Retourne le résultat avec le solde mis à jour si online,
  /// ou l'ID local + statut pending si offline.
  Future<PaiementResult> enregistrer({
    required String chauffeurId,
    required String vehiculeId,
    required double montant,
    required String date,
    String mode = 'kkiapay',
  }) async {
    final isConnected = await connectivity.isConnected;

    if (isConnected) {
      return _enregistrerOnline(
        chauffeurId: chauffeurId,
        vehiculeId: vehiculeId,
        montant: montant,
        date: date,
        mode: mode,
      );
    } else {
      return _enregistrerOffline(
        chauffeurId: chauffeurId,
        vehiculeId: vehiculeId,
        montant: montant,
        date: date,
        mode: mode,
      );
    }
  }

  /// Enregistrement en ligne — appel API direct
  Future<PaiementResult> _enregistrerOnline({
    required String chauffeurId,
    required String vehiculeId,
    required double montant,
    required String date,
    String mode = 'kkiapay',
  }) async {
    try {
      final response = await apiClient.post('/paiements', data: {
        'chauffeur_id': chauffeurId,
        'vehicule_id': vehiculeId,
        'montant': montant,
        'date': date,
        'mode': mode,
        'synchronise_offline': false,
      });

      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>;
      final paiementData = data['paiement'] as Map<String, dynamic>;
      final soldeData = data['solde'] as Map<String, dynamic>;

      AppLogger.i('[Paiement] Enregistré en ligne: ${paiementData['id']} — $montant FCFA');

      return PaiementResult(
        paiement: PaiementModel.fromJson(paiementData),
        solde: SoldeInfo(
          totalVerseAvant: _toDouble(soldeData['total_verse_avant']),
          montantPaye: _toDouble(soldeData['montant_paye']),
          nouveauSolde: _toDouble(soldeData['nouveau_solde']),
          pourcentageRembourse: _toDouble(soldeData['pourcentage_rembourse']),
        ),
        isOffline: false,
      );
    } catch (e) {
      AppLogger.e('[Paiement] Erreur en ligne, fallback offline: $e');
      // Fallback offline si l'API échoue (possible perte de connexion pendant l'appel)
      return _enregistrerOffline(
        chauffeurId: chauffeurId,
        vehiculeId: vehiculeId,
        montant: montant,
        date: date,
        mode: mode,
      );
    }
  }

  /// Enregistrement hors-ligne — stockage Hive + file de sync
  Future<PaiementResult> _enregistrerOffline({
    required String chauffeurId,
    required String vehiculeId,
    required double montant,
    required String date,
    String mode = 'kkiapay',
  }) async {
    final paiement = PaiementModel(
      id: _uuid.v4(),
      chauffeurId: chauffeurId,
      vehiculeId: vehiculeId,
      montant: montant,
      date: date,
      mode: mode,
      synchroniseOffline: false,
      dateEnregistrement: DateTime.now(),
    );

    final id = await offlineStorage.saveOfflinePayment(paiement);
    AppLogger.i('[Paiement] Enregistré hors-ligne: $id — $montant FCFA');

    return PaiementResult(
      paiement: paiement,
      solde: null, // Pas de calcul de solde en offline
      isOffline: true,
    );
  }

  /// Récupère l'historique des paiements (API si online, local si offline)
  Future<List<PaiementModel>> getHistorique({
    String? chauffeurId,
    String? vehiculeId,
    String? dateDebut,
    String? dateFin,
    String? mode,
    int limit = 200,
  }) async {
    final isConnected = await connectivity.isConnected;

    if (isConnected) {
      try {
        final params = <String, dynamic>{'limit': limit};
        if (chauffeurId != null) params['chauffeur_id'] = chauffeurId;
        if (vehiculeId != null) params['vehicule_id'] = vehiculeId;
        if (dateDebut != null) params['date_debut'] = dateDebut;
        if (dateFin != null) params['date_fin'] = dateFin;
        if (mode != null) params['mode'] = mode;

        final response = await apiClient.get('/paiements', queryParameters: params);
        final responseData = response.data as Map<String, dynamic>;
        return (responseData['data'] as List)
            .map((e) => PaiementModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        AppLogger.e('[Paiement] Erreur récupération historique: $e');
        return [];
      }
    } else {
      // Retourner les paiements offline en attendant
      return offlineStorage.getAllOfflinePayments();
    }
  }

  /// Récupère les paiements en attente de sync
  List<Map<String, dynamic>> getPendingSync() {
    return offlineStorage.getPendingSyncItems();
  }

  /// Nombre de paiements en attente
  int get pendingCount => offlineStorage.pendingSyncCount;
}

/// Résultat d'un enregistrement de paiement
class PaiementResult {
  final PaiementModel paiement;
  final SoldeInfo? solde;
  final bool isOffline;

  const PaiementResult({
    required this.paiement,
    this.solde,
    this.isOffline = false,
  });
}

/// Information de solde après un paiement
class SoldeInfo {
  final double totalVerseAvant;
  final double montantPaye;
  final double nouveauSolde;
  final double pourcentageRembourse;

  const SoldeInfo({
    required this.totalVerseAvant,
    required this.montantPaye,
    required this.nouveauSolde,
    required this.pourcentageRembourse,
  });
}

// ─── Provider ────────────────────────────────────────────────────────────────

final paiementRepositoryProvider = Provider<PaiementRepository>((ref) {
  return PaiementRepository(
    apiClient: ref.read(apiClientProvider),
    offlineStorage: ref.read(offlineStorageProvider),
    connectivity: ref.read(connectivityProvider),
  );
});
