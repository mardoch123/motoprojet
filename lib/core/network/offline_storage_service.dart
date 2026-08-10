import 'package:hive_flutter/hive_flutter.dart';
import 'package:motoprojet/core/constants/app_constants.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import 'package:motoprojet/shared/models/paiement_model.dart';
import 'package:uuid/uuid.dart';

/// Stockage local des paiements hors-ligne avec file d'attente de synchronisation
class OfflineStorageService {
  late Box<Map> _offlinePaymentsBox;
  late Box<Map> _syncQueueBox;
  final _uuid = const Uuid();

  Future<void> init() async {
    await Hive.initFlutter();
    _offlinePaymentsBox = await Hive.openBox(AppConstants.offlinePaymentsBox);
    _syncQueueBox = await Hive.openBox(AppConstants.syncQueueBox);
    AppLogger.i('OfflineStorage initialisé — ${_offlinePaymentsBox.length} paiements en cache');
  }

  // ─── Paiements hors-ligne ──────────────────────────────────────────────────

  /// Sauvegarde un paiement saisi hors-ligne
  Future<String> saveOfflinePayment(PaiementModel paiement) async {
    final id = paiement.id.isNotEmpty ? paiement.id : _uuid.v4();
    final offlinePayment = PaiementModel(
      id: id,
      chauffeurId: paiement.chauffeurId,
      vehiculeId: paiement.vehiculeId,
      montant: paiement.montant,
      date: paiement.date,
      mode: paiement.mode,
      synchroniseOffline: false,
      dateEnregistrement: DateTime.now(),
    );
    await _offlinePaymentsBox.put(id, offlinePayment.toHiveMap());
    await addToSyncQueue(offlinePayment);
    AppLogger.d('Paiement hors-ligne sauvegardé: $id — ${paiement.montant} FCFA');
    return id;
  }

  /// Récupère tous les paiements hors-ligne
  List<PaiementModel> getAllOfflinePayments() {
    return _offlinePaymentsBox.values
        .map((map) => PaiementModel.fromHiveMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => b.dateEnregistrement.compareTo(a.dateEnregistrement));
  }

  /// Supprime un paiement hors-ligne après synchronisation réussie
  Future<void> removeOfflinePayment(String id) async {
    await _offlinePaymentsBox.delete(id);
    await _syncQueueBox.delete(id);
    AppLogger.d('Paiement hors-ligne supprimé: $id');
  }

  // ─── File de synchronisation ───────────────────────────────────────────────

  /// Ajoute un paiement à la file de synchronisation
  Future<void> addToSyncQueue(PaiementModel paiement) async {
    final syncEntry = {
      'id': paiement.id,
      'type': 'paiement',
      'data': paiement.toHiveMap(),
      'attemptCount': 0,
      'lastAttempt': null,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _syncQueueBox.put(paiement.id, syncEntry);
    AppLogger.d('Ajouté à la file de sync: ${paiement.id}');
  }

  /// Récupère les éléments en attente de synchronisation
  List<Map<String, dynamic>> getPendingSyncItems() {
    return _syncQueueBox.values
        .map((map) => Map<String, dynamic>.from(map))
        .where((item) => item['type'] == 'paiement')
        .toList()
      ..sort((a, b) => (a['createdAt'] as String).compareTo(b['createdAt'] as String));
  }

  /// Met à jour le compteur de tentatives après un échec de sync
  Future<void> incrementSyncAttempt(String id) async {
    final item = _syncQueueBox.get(id);
    if (item != null) {
      final updated = Map<String, dynamic>.from(item);
      updated['attemptCount'] = (updated['attemptCount'] as int? ?? 0) + 1;
      updated['lastAttempt'] = DateTime.now().toIso8601String();
      await _syncQueueBox.put(id, updated);
    }
  }

  /// Nombre d'éléments en attente de sync
  int get pendingSyncCount => _syncQueueBox.length;

  /// Ferme les boxes
  Future<void> close() async {
    await _offlinePaymentsBox.close();
    await _syncQueueBox.close();
  }
}
