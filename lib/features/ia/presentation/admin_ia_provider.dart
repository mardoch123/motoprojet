import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motoprojet/core/network/providers.dart';
import 'package:motoprojet/core/utils/app_logger.dart';

// ─── Modèles de données ──────────────────────────────────────────────────────

class AdminObjectif {
  final String id;
  final String libelle;
  final double valeurCible;
  final String unite;
  final int delaiMois;

  const AdminObjectif({
    required this.id,
    required this.libelle,
    required this.valeurCible,
    required this.unite,
    required this.delaiMois,
  });

  factory AdminObjectif.fromJson(Map<String, dynamic> json) {
    return AdminObjectif(
      id: json['id'] as String,
      libelle: json['libelle'] as String,
      valeurCible: (json['valeur_cible'] as num).toDouble(),
      unite: json['unite'] as String,
      delaiMois: json['delai_mois'] as int,
    );
  }
}

class AdminRapport {
  final String id;
  final String type; // 'hebdo' | 'chat' | 'manuel'
  final String rapport;
  final List<String> actionsProposees;
  final String trajectoire; // 'en_avance' | 'a_temps' | 'en_retard'
  final String modeleUtilise;
  final DateTime date;

  const AdminRapport({
    required this.id,
    required this.type,
    required this.rapport,
    required this.actionsProposees,
    required this.trajectoire,
    required this.modeleUtilise,
    required this.date,
  });

  factory AdminRapport.fromJson(Map<String, dynamic> json) {
    return AdminRapport(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'hebdo',
      rapport: json['rapport'] as String,
      actionsProposees: json['actions_proposees'] is List
          ? List<String>.from(json['actions_proposees'] as List)
          : [],
      trajectoire: json['trajectoire'] as String? ?? 'non_evaluee',
      modeleUtilise: json['modele_utilise'] as String? ?? 'claude',
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class ChatMessage {
  final String id;
  final String question;
  final String reponse;
  final DateTime date;

  const ChatMessage({
    required this.id,
    required this.question,
    required this.reponse,
    required this.date,
  });
}

// ─── États ────────────────────────────────────────────────────────────────────

enum AdminIaStatus { initial, loading, success, error }

class AdminIaState {
  final AdminIaStatus rapportStatus;
  final AdminIaStatus chatStatus;
  final AdminRapport? dernierRapport;
  final List<AdminRapport> historique;
  final List<AdminObjectif> objectifs;
  final List<ChatMessage> chatMessages;
  final String? errorMessage;
  final bool rapportFrais;

  // Stats
  final int totalRapports;
  final int rapportsEnRetard;
  final int rapportsAtemps;
  final int rapportsEnAvance;

  const AdminIaState({
    this.rapportStatus = AdminIaStatus.initial,
    this.chatStatus = AdminIaStatus.initial,
    this.dernierRapport,
    this.historique = const [],
    this.objectifs = const [],
    this.chatMessages = const [],
    this.errorMessage,
    this.rapportFrais = false,
    this.totalRapports = 0,
    this.rapportsEnRetard = 0,
    this.rapportsAtemps = 0,
    this.rapportsEnAvance = 0,
  });

  AdminIaState copyWith({
    AdminIaStatus? rapportStatus,
    AdminIaStatus? chatStatus,
    AdminRapport? dernierRapport,
    List<AdminRapport>? historique,
    List<AdminObjectif>? objectifs,
    List<ChatMessage>? chatMessages,
    String? errorMessage,
    bool? rapportFrais,
    int? totalRapports,
    int? rapportsEnRetard,
    int? rapportsAtemps,
    int? rapportsEnAvance,
    bool clearError = false,
  }) {
    return AdminIaState(
      rapportStatus: rapportStatus ?? this.rapportStatus,
      chatStatus: chatStatus ?? this.chatStatus,
      dernierRapport: dernierRapport ?? this.dernierRapport,
      historique: historique ?? this.historique,
      objectifs: objectifs ?? this.objectifs,
      chatMessages: chatMessages ?? this.chatMessages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      rapportFrais: rapportFrais ?? this.rapportFrais,
      totalRapports: totalRapports ?? this.totalRapports,
      rapportsEnRetard: rapportsEnRetard ?? this.rapportsEnRetard,
      rapportsAtemps: rapportsAtemps ?? this.rapportsAtemps,
      rapportsEnAvance: rapportsEnAvance ?? this.rapportsEnAvance,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final adminIaProvider =
    StateNotifierProvider<AdminIaNotifier, AdminIaState>((ref) {
  return AdminIaNotifier(ref);
});

class AdminIaNotifier extends StateNotifier<AdminIaState> {
  final Ref _ref;

  AdminIaNotifier(this._ref) : super(const AdminIaState());

  // ─── Charger le dernier rapport ──────────────────────────────────────────
  Future<void> chargerRapport({bool force = false}) async {
    state = state.copyWith(rapportStatus: AdminIaStatus.loading, clearError: true);

    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.get(
        '/ia/admin/rapport',
        queryParameters: force ? {'force': 'true'} : null,
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final rapport = AdminRapport.fromJson(data);

      state = state.copyWith(
        rapportStatus: AdminIaStatus.success,
        dernierRapport: rapport,
        rapportFrais: data['frais'] as bool? ?? false,
      );

      AppLogger.i('[IA-Admin] Rapport chargé (${rapport.trajectoire})');
    } catch (e) {
      state = state.copyWith(
        rapportStatus: AdminIaStatus.error,
        errorMessage: 'Impossible de charger le rapport IA.',
      );
      AppLogger.e('[IA-Admin] Erreur chargement rapport: $e');
    }
  }

  // ─── Envoyer une question chat ───────────────────────────────────────────
  Future<void> envoyerChat(String question) async {
    if (question.trim().isEmpty) return;

    state = state.copyWith(chatStatus: AdminIaStatus.loading, clearError: true);

    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.post('/ia/admin/chat', data: {'question': question});

      final data = response.data['data'] as Map<String, dynamic>;

      final message = ChatMessage(
        id: data['id'] as String,
        question: question.trim(),
        reponse: data['reponse'] as String,
        date: DateTime.parse(data['date'] as String),
      );

      state = state.copyWith(
        chatStatus: AdminIaStatus.success,
        chatMessages: [message, ...state.chatMessages],
      );

      AppLogger.i('[IA-Admin] Réponse chat reçue');
    } catch (e) {
      state = state.copyWith(
        chatStatus: AdminIaStatus.error,
        errorMessage: 'Erreur lors de l\'envoi de la question.',
      );
      AppLogger.e('[IA-Admin] Erreur chat: $e');
    }
  }

  // ─── Charger l'historique ────────────────────────────────────────────────
  Future<void> chargerHistorique({int limit = 20}) async {
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.get(
        '/ia/admin/historique',
        queryParameters: {'limit': limit},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final stats = data['stats'] as Map<String, dynamic>;
      final trajectoires = stats['trajectoires'] as Map<String, dynamic>;

      final rapports = (data['rapports'] as List)
          .map((r) => AdminRapport.fromJson(r as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        historique: rapports,
        totalRapports: stats['total'] as int? ?? 0,
        rapportsEnRetard: trajectoires['en_retard'] as int? ?? 0,
        rapportsAtemps: trajectoires['a_temps'] as int? ?? 0,
        rapportsEnAvance: trajectoires['en_avance'] as int? ?? 0,
      );
    } catch (e) {
      AppLogger.e('[IA-Admin] Erreur chargement historique: $e');
    }
  }

  // ─── Charger les objectifs ───────────────────────────────────────────────
  Future<void> chargerObjectifs() async {
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.get('/ia/admin/objectifs');

      final data = response.data['data'] as List;
      final objectifs = data
          .map((o) => AdminObjectif.fromJson(o as Map<String, dynamic>))
          .toList();

      state = state.copyWith(objectifs: objectifs);
    } catch (e) {
      AppLogger.e('[IA-Admin] Erreur chargement objectifs: $e');
    }
  }

  // ─── Ajouter un objectif ─────────────────────────────────────────────────
  Future<bool> ajouterObjectif({
    required String libelle,
    required double valeurCible,
    required String unite,
    int delaiMois = 12,
  }) async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.put('/ia/admin/objectif', data: {
        'libelle': libelle,
        'valeur_cible': valeurCible,
        'unite': unite,
        'delai_mois': delaiMois,
      });

      // Recharger les objectifs
      await chargerObjectifs();
      AppLogger.i('[IA-Admin] Objectif ajouté : $libelle');
      return true;
    } catch (e) {
      AppLogger.e('[IA-Admin] Erreur ajout objectif: $e');
      return false;
    }
  }
}
